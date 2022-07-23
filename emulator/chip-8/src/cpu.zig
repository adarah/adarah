const std = @import("std");
const Keypad = @import("./keypad.zig").Keypad;
const Timer = @import("./timer.zig").Timer;
const panic = @import("./util.zig").panic;
const fmt = std.fmt;
const rand = std.rand;

const CpuOptions = struct {
    memory: *[4096]u8,
    keypad: *Keypad,
    sound_timer: *Timer,
    delay_timer: *Timer,
    seed: u64,
    shift_quirk: bool,
    register_quirk: bool,
};

pub const Cpu = struct {
    // Memory
    mem: *[4096]u8,

    // Helpers
    keypad: *Keypad,
    sound_timer: *Timer,
    delay_timer: *Timer,
    prng: rand.DefaultPrng,

    // Quirks
    shift_quirk: bool,
    register_quirk: bool,
    wrap_quirk: bool,

    const Self = @This();
    // Special register addresses
    const PC_ADDR = 0x50;
    const SP_ADDR = 0x52;
    const I_ADDR = 0x54;

    pub fn init(options: CpuOptions) Self {
        var prng = rand.DefaultPrng.init(options.seed);

        return Self{
            .mem = options.memory,
            .prng = prng,
            .keypad = options.keypad,
            .sound_timer = options.sound_timer,
            .delay_timer = options.delay_timer,
            .shift_quirk = options.shift_quirk,
            .register_quirk = options.register_quirk,
            .wrap_quirk = true,
        };
    }

    inline fn getWord(self: *Self, address: u16) u16 {
        return std.mem.readIntBig(u16, self.mem[address..][0..2]);
    }

    inline fn setWord(self: *Self, address: u16, value: u16) void {
        std.mem.writeIntBig(u16, self.mem[address..][0..2], value);
    }

    // PC, SP, and I are stored in the memory for convenience in exporting them to js
    pub inline fn PC(self: *Self) u16 {
        return self.getWord(PC_ADDR);
    }

    inline fn setPC(self: *Self, address: u16) void {
        self.setWord(PC_ADDR, address);
    }

    pub inline fn SP(self: *Self) u16 {
        return self.getWord(SP_ADDR);
    }

    inline fn setSP(self: *Self, address: u16) void {
        self.setWord(SP_ADDR, address);
    }

    pub inline fn I(self: *Self) u16 {
        return self.getWord(I_ADDR);
    }

    inline fn setI(self: *Self, address: u16) void {
        self.setWord(I_ADDR, address);
    }

    pub inline fn stack(self: *Self) *[48]u8 {
        return self.mem[0xEA0..0xED0];
    }

    pub inline fn registers(self: *Self) *[16]u8 {
        return self.mem[0xEF0..0xF00];
    }

    pub inline fn displayBuffer(self: *Self) *[256]u8 {
        return self.mem[0xF00..];
    }

    fn stackPush(self: *Self, address: u16) void {
        // Chip-8 is big endian, so the most significant byte goes in a lower memory address
        const sp = self.SP();
        self.setWord(sp - 1, address);
        self.setSP(sp - 2);
    }

    fn stackPop(self: *Self) u16 {
        // Chip-8 is big endian, so the most significant byte goes in a lower memory address
        const sp = self.SP();
        const stack_top = self.getWord(sp + 1);
        self.setSP(sp + 2);
        return stack_top;
    }

    fn stackPeek(self: *Self) u16 {
        // SP always points to next available position, so SP+1 contains the top of the stack
        // (remember, stacks grow downwards)
        return self.getWord(self.SP() + 1);
    }

    inline fn incrementPc(self: *Self) void {
        self.setPC(self.PC() + 2);
    }

    fn fetchDecode(self: *Self, pc: u16) struct { a: u4, b: u4, c: u4, d: u4, lsb: u8, nnn: u16 } {
        const first = self.mem[pc];
        const second = self.mem[pc + 1];

        const a: u4 = @truncate(u4, @shrExact(first & 0xF0, 4));
        const b: u4 = @truncate(u4, first);
        const c: u4 = @truncate(u4, @shrExact(second & 0xF0, 4));
        const d: u4 = @truncate(u4, second);

        const nnn: u16 = @shlExact(@as(u16, b), 8) + second;

        return .{ .a = a, .b = b, .c = c, .d = d, .nnn = nnn, .lsb = second };
    }

    pub fn fetchDecodeExecute(self: *Self) void {
        const pc = self.PC();
        const decoded = self.fetchDecode(pc);

        const a = decoded.a;
        const b = decoded.b;
        const c = decoded.c;
        const d = decoded.d;
        const lsb = decoded.lsb;
        const nnn = decoded.nnn;

        {
            std.log.debug("fetched: {}", .{fmt.fmtSliceHexUpper(self.mem[pc .. pc + 2])});
            std.log.debug("PC: {}", .{pc});
        }

        switch (a) {
            0 => {
                switch (lsb) {
                    0xE0 => self.clearScreen(),
                    0xEE => self.returnFromSubroutine(),
                    else => self.syscall(nnn) catch |err| {
                        panic("syscall error: {}", .{err});
                    },
                }
            },
            1 => self.jump(nnn),
            2 => self.callSubroutine(nnn),
            3 => self.skipIfEqualLiteral(b, lsb),
            4 => self.skipIfNotEqualLiteral(b, lsb),
            5 => self.skipIfEqual(b, c),
            6 => self.storeLiteral(b, lsb),
            7 => self.addLiteral(b, lsb),
            8 => {
                switch (d) {
                    0 => self.store(b, c),
                    1 => self.bitwiseOr(b, c),
                    2 => self.bitwiseAnd(b, c),
                    3 => self.bitwiseXor(b, c),
                    4 => self.add(b, c),
                    5 => self.sub(b, c),
                    6 => self.shiftRight(b, c),
                    7 => self.subStore(b, c),
                    0xE => self.shiftLeft(b, c),
                    else => panic("unknown instruction: {}", .{fmt.fmtSliceHexUpper(self.mem[pc .. pc + 2])}),
                }
            },
            9 => self.skipIfNotEqual(b, c),
            0xA => self.storeAddressI(nnn),
            0xB => self.jumpWithOffset(nnn),
            0xC => self.genRandom(b, lsb),
            0xD => self.draw(b, c, d),
            0xE => {
                switch (lsb) {
                    0x9E => self.skipIfPressed(b),
                    0xA1 => self.skipIfNotPressed(b),
                    else => panic("unknown instruction: {}", .{fmt.fmtSliceHexUpper(self.mem[pc .. pc + 2])}),
                }
            },
            0xF => {
                switch (lsb) {
                    0x07 => self.storeDelayTimer(b),
                    0x0A => self.waitForKeypress(b),
                    0x15 => self.setDelayTimer(b),
                    0x18 => self.setSoundTimer(b),
                    0x1E => self.addI(b),
                    0x29 => self.setSprite(b),
                    0x33 => self.setBcd(b),
                    0x55 => self.dumpRegisters(b),
                    0x65 => self.restoreRegisters(b),
                    else => panic("unknown instruction: {}", .{fmt.fmtSliceHexUpper(self.mem[pc .. pc + 2])}),
                }
            },
        }
    }

    // Instructions

    pub fn syscall(self: *Self, code: u16) !void {
        switch (code) {
            0x004B => {}, // This machine code subroutine just turns on the display, so we do't have to do anything
            else => return error.NotImplemented,
        }
        self.incrementPc();
    }

    pub fn callSubroutine(self: *Self, address: u16) void {
        self.stackPush(self.PC() + 2);
        self.setPC(address);
    }

    pub fn clearScreen(self: *Self) void {
        for (self.displayBuffer()) |*b| {
            b.* = 0;
        }
        self.incrementPc();
    }

    pub fn returnFromSubroutine(self: *Self) void {
        self.setPC(self.stackPop());
    }

    pub fn jump(self: *Self, address: u16) void {
        self.setPC(address);
    }

    pub fn skipIfEqualLiteral(self: *Self, register: u4, value: u8) void {
        const V = self.registers();
        if (V[register] == value) {
            self.incrementPc();
        }
        self.incrementPc();
    }

    pub fn skipIfNotEqualLiteral(self: *Self, register: u4, value: u8) void {
        const V = self.registers();
        if (V[register] != value) {
            self.incrementPc();
        }
        self.incrementPc();
    }

    pub fn skipIfEqual(self: *Self, registerX: u4, registerY: u4) void {
        const V = self.registers();
        if (V[registerX] == V[registerY]) {
            self.incrementPc();
        }
        self.incrementPc();
    }

    pub fn storeLiteral(self: *Self, register: u4, value: u8) void {
        const V = self.registers();
        V[register] = value;
        self.incrementPc();
    }

    pub fn addLiteral(self: *Self, register: u4, value: u8) void {
        const V = self.registers();
        V[register] +%= value;
        self.incrementPc();
    }

    pub fn store(self: *Self, registerX: u4, registerY: u4) void {
        const V = self.registers();
        V[registerX] = V[registerY];
        self.incrementPc();
    }

    pub fn bitwiseOr(self: *Self, registerX: u4, registerY: u4) void {
        const V = self.registers();
        V[registerX] |= V[registerY];
        self.incrementPc();
    }

    pub fn bitwiseAnd(self: *Self, registerX: u4, registerY: u4) void {
        const V = self.registers();
        V[registerX] &= V[registerY];
        self.incrementPc();
    }

    pub fn bitwiseXor(self: *Self, registerX: u4, registerY: u4) void {
        const V = self.registers();
        V[registerX] ^= V[registerY];
        self.incrementPc();
    }

    pub fn add(self: *Self, registerX: u4, registerY: u4) void {
        const V = self.registers();
        const overflow = @addWithOverflow(u8, V[registerX], V[registerY], &V[registerX]);
        V[0xF] = @boolToInt(overflow);
        self.incrementPc();
    }

    pub fn sub(self: *Self, registerX: u4, registerY: u4) void {
        const V = self.registers();
        const underflow = @subWithOverflow(u8, V[registerX], V[registerY], &V[registerX]);
        V[0xF] = @boolToInt(!underflow);
        self.incrementPc();
    }

    pub fn shiftRight(self: *Self, registerX: u4, registerY: u4) void {
        const V = self.registers();
        if (self.shift_quirk) {
            V[0xF] = V[registerX] & 1;
            V[registerX] >>= 1;
        } else {
            V[0xF] = V[registerY] & 1;
            V[registerX] = V[registerY] >> 1;
        }
        self.incrementPc();
    }

    pub fn subStore(self: *Self, registerX: u4, registerY: u4) void {
        const V = self.registers();
        const underflow = @subWithOverflow(u8, V[registerY], V[registerX], &V[registerX]);
        V[0xF] = @boolToInt(!underflow);
        self.incrementPc();
    }

    // TODO: Implement VF setting alternative behaviour
    pub fn shiftLeft(self: *Self, registerX: u4, registerY: u4) void {
        const V = self.registers();
        var overflow: bool = undefined;
        if (self.shift_quirk) {
            overflow = @shlWithOverflow(u8, V[registerX], 1, &V[registerX]);
        } else {
            overflow = @shlWithOverflow(u8, V[registerY], 1, &V[registerX]);
        }
        V[0xF] = @boolToInt(overflow);
        self.incrementPc();
    }

    pub fn skipIfNotEqual(self: *Self, registerX: u4, registerY: u4) void {
        const V = self.registers();
        if (V[registerX] != V[registerY]) {
            self.incrementPc();
        }
        self.incrementPc();
    }

    pub fn storeAddressI(self: *Self, address: u16) void {
        self.setI(address);
        self.incrementPc();
    }

    pub fn jumpWithOffset(self: *Self, address: u16) void {
        const V = self.registers();
        self.setPC(V[0] + address);
    }

    pub fn genRandom(self: *Self, register: u4, mask: u8) void {
        const V = self.registers();
        const r = self.prng.random().int(u8);
        V[register] = r & mask;
        self.incrementPc();
    }

    // TODO: Implement alternative wrapping behaviour
    // Pixel addresses might not perfectly align with our bytes (happens on 87.5% of cases)
    // When painting pixels, we should fetch the current and the "next" byte.
    // The "next" byte might not be the immediatelly following byte in case we are near one of the edges of the screen.
    // In such situations, we need to wrap around.
    // Once we obtain both bytes, we split the mask in 2 parts and apply it to both of them.
    // Pseudocode:
    // Given the top-left "screen address" of a "pixel row", find the 2 bytes that will be affected
    // Split the mask in two parts, and apply them to both bytes via XOR
    // If any bit is ever unset, we set the VF register.
    pub fn draw(self: *Self, registerX: u4, registerY: u4, height: u8) void {
        const V = self.registers();
        const _I = self.I();
        const y = @intCast(u8, @mod(@as(usize, V[registerY]) * 8, 256)); // 31*8=248 at most
        const x: usize = V[registerX];
        // In most situations, drawing something on the screen will require applying a mask to two differente bytes
        // Looking at X + 8 (with modulo) guarantees that we look at the next byte in the row (wrapped if needed).
        // But we don't want the next byte if X is exactly divisible by 8 since the mask is supposed to only affect one byte,
        // in such situations, so we use X + 7 instead.
        // This guarantees that we grab the next byte if and only if X is not divisible by 8.
        const x_first = @mod(x, 64) / 8; // 7 at most
        const x_second = @mod(x + 7, 64) / 8; // 7 at most
        const bits_first = @intCast(u3, @mod(@mod(x, 64), 8)); // 0-7
        const display = self.displayBuffer();
        V[0xF] = 0;
        var i: usize = 0;
        while (i < height) : (i += 1) {
            const offset = 8 * i;
            const sprite_data = self.mem[_I + i];
            const masks = Cpu.splitMask(sprite_data, bits_first);
            const pos_first = @mod(y + x_first + offset, 256);
            const pos_second = @mod(y + x_second + offset, 256);

            // Flips from 1 to 0 happens when the mask and the number have 1s in the same position
            // So we apply a binary AND the check if there's any remaining ones. This can
            // be done by verifying if the number if larger than 0
            V[0xF] |= @boolToInt((masks.left & display[pos_first]) != 0);
            V[0xF] |= @boolToInt((masks.right & display[pos_second]) != 0);

            display[pos_first] ^= masks.left;
            display[pos_second] ^= masks.right;
        }
        self.incrementPc();
    }

    // splitMask splits a mask in two, leaving 8-N bits in the left mask, and N bits in the right mask
    inline fn splitMask(mask: u8, N: u3) struct { left: u8, right: u8 } {
        if (N == 0) {
            return .{ .left = mask, .right = 0 };
        }
        const lsb_mask = (@as(u8, 1) << N) - 1;
        const left = mask >> N;
        const right = @shlExact(mask & lsb_mask, @intCast(u3, 8 - @as(u8, N)));
        return .{ .left = left, .right = right };
    }

    pub fn skipIfPressed(self: *Self, register: u4) void {
        const V = self.registers();
        const key = @intCast(u4, V[register]);
        if (self.keypad.isPressed(key)) {
            self.incrementPc();
        }
        self.incrementPc();
    }

    pub fn skipIfNotPressed(self: *Self, register: u4) void {
        const V = self.registers();
        const key = @intCast(u4, V[register]);
        if (!self.keypad.isPressed(key)) {
            self.incrementPc();
        }
        self.incrementPc();
    }

    pub fn storeDelayTimer(self: *Self, register: u4) void {
        const V = self.registers();
        V[register] = self.delay_timer.value;
        self.incrementPc();
    }

    pub fn waitForKeypress(self: *Self, register: u4) void {
        std.log.debug("waiting for any key", .{});
        const key = await async self.keypad.waitForKeypress();
        std.log.debug("got key! {}", .{key});
        const V = self.registers();
        V[register] = key;
        self.incrementPc();
    }

    pub fn setDelayTimer(self: *Self, register: u4) void {
        const V = self.registers();
        self.delay_timer.set(V[register]);
        self.incrementPc();
    }

    pub fn setSoundTimer(self: *Self, register: u4) void {
        const V = self.registers();
        var val = V[register];
        // Setting the sound timer to values below 2 is supposed to be a NOOP
        // https://github.com/mattmikolay/chip-8/wiki/CHIP%E2%80%908-Technical-Reference#timers
        if (val < 2) {
            val = 0;
        }
        self.sound_timer.set(val);
        self.incrementPc();
    }

    pub fn addI(self: *Self, register: u4) void {
        const V = self.registers();
        self.setI(self.I() + V[register]);
        self.incrementPc();
    }

    pub fn setSprite(self: *Self, register: u4) void {
        const V = self.registers();
        self.setI(V[register] * 5);
        self.incrementPc();
    }

    pub fn setBcd(self: *Self, register: u4) void {
        const V = self.registers();
        const _I = self.I();
        const val = V[register];
        self.mem[_I] = val / 100;
        self.mem[_I + 1] = @mod(val, 100) / 10;
        self.mem[_I + 2] = @mod(val, 10);
        self.incrementPc();
    }

    pub fn dumpRegisters(self: *Self, register: u4) void {
        const V = self.registers();
        const _I = self.I();
        var i: usize = 0;
        while (i <= register) : (i += 1) {
            self.mem[_I + i] = V[i];
        }
        if (!self.register_quirk) {
            self.setI(_I + register + 1);
        }
        self.incrementPc();
    }

    pub fn restoreRegisters(self: *Self, register: u4) void {
        const V = self.registers();
        const _I = self.I();
        var i: usize = 0;
        while (i <= register) : (i += 1) {
            V[i] = self.mem[_I + i];
        }
        if (!self.register_quirk) {
            self.setI(_I + register + 1);
        }
        self.incrementPc();
    }
};

// Tests

const expect = std.testing.expect;
const expectError = std.testing.expectError;
const print = std.debug.print;
const Loader = @import("./loader.zig").Loader;

fn expectEqual(comptime T: type, expected: T, actual: T) !void {
    try std.testing.expectEqual(expected, actual);
}

var test_keypad: Keypad = undefined;
var test_sound_timer: Timer = undefined;
var test_delay_timer: Timer = undefined;
var test_memory: [4096]u8 = undefined;

fn getTestCpu() Cpu {
    Loader.initMem(&test_memory);
    test_keypad = Keypad.init();
    test_sound_timer = Timer.init(0);
    test_delay_timer = Timer.init(0);
    return Cpu.init(.{ .seed = 0, .memory = &test_memory, .keypad = &test_keypad, .sound_timer = &test_sound_timer, .delay_timer = &test_delay_timer, .shift_quirk = false, .register_quirk = false });
}

test "Cpu makes syscall (0NNN)" {
    var cpu = getTestCpu();
    cpu.syscall(0x004B) catch |err| {
        panic("expected this syscall call to be implemented, got {}", .{err});
    };
    try expectEqual(u16, 0x1FE, cpu.PC());
    try expectError(error.NotImplemented, cpu.syscall(0x300));
}

test "Cpu clears screens (00E0)" {
    var cpu = getTestCpu();
    for (cpu.displayBuffer()) |*b, i| {
        b.* = @intCast(u8, i);
    }

    cpu.clearScreen();
    for (cpu.displayBuffer()) |b| {
        try expectEqual(u8, 0, b);
    }
    try expectEqual(u16, 0x1FE, cpu.PC());
}

test "Cpu returns from subroutine (00EE)" {
    var cpu = getTestCpu();
    cpu.stackPush(0x500);
    cpu.stackPush(0x800);

    cpu.returnFromSubroutine();
    try expectEqual(u16, 0xECD, cpu.SP());
    try expectEqual(u16, 0x800, cpu.PC());

    cpu.returnFromSubroutine();
    try expectEqual(u16, 0xECF, cpu.SP());
    try expectEqual(u16, 0x500, cpu.PC());
}

test "Cpu jumps to address (1NNN)" {
    var cpu = getTestCpu();

    cpu.jump(0x300);
    try expectEqual(u16, 0x300, cpu.PC());

    cpu.jump(0x500);
    try expectEqual(u16, 0x500, cpu.PC());
}

test "Cpu calls subroutine (2NNN)" {
    var cpu = getTestCpu();

    cpu.callSubroutine(0x300);
    try expectEqual(u16, 0x300, cpu.PC());
    try expectEqual(u16, 0xECD, cpu.SP());
    try expectEqual(u16, 0x1FE, cpu.stackPeek());

    cpu.callSubroutine(0x500);
    try expectEqual(u16, 0x500, cpu.PC());
    try expectEqual(u16, 0xECB, cpu.SP());
    try expectEqual(u16, 0x302, cpu.stackPeek());
}

test "Cpu skips next instruction if VX equals literal (3XNN)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 0xFF;

    cpu.skipIfEqualLiteral(0xA, 0xFF);
    try expectEqual(u16, 0x200, cpu.PC());

    cpu.skipIfEqualLiteral(0xA, 0xAB);
    try expectEqual(u16, 0x202, cpu.PC());
}

test "Cpu skips next instruction if VX not equals literal (4XNN)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 0xFF;

    cpu.skipIfNotEqualLiteral(0xA, 0xBC);
    try expectEqual(u16, 0x200, cpu.PC());

    cpu.skipIfNotEqualLiteral(0xA, 0xFF);
    try expectEqual(u16, 0x202, cpu.PC());
}

test "Cpu skips next instruction if VX equals VY (5XY0)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 0xFF;
    V[0xB] = 0xFF;

    cpu.skipIfEqual(0xA, 0xB);
    try expectEqual(u16, 0x200, cpu.PC());

    V[0xB] = 0x21;

    cpu.skipIfEqual(0xA, 0xB);
    try expectEqual(u16, 0x202, cpu.PC());
}

test "Cpu stores literal into register (6XNN)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    cpu.storeLiteral(0xA, 0xFF);
    try expectEqual(u8, 0xFF, V[0xA]);
    try expectEqual(u16, 0x1FE, cpu.PC());

    cpu.storeLiteral(0xC, 0xCC);
    try expectEqual(u8, 0xCC, V[0xC]);
    try expectEqual(u16, 0x200, cpu.PC());
}

test "Cpu adds literal into register (7XNN)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    cpu.addLiteral(0xA, 0xFA);
    try expectEqual(u8, 0xFA, V[0xA]);
    try expectEqual(u16, 0x1FE, cpu.PC());

    // Overflows
    cpu.addLiteral(0xA, 0x06);
    try expectEqual(u8, 0x00, V[0xA]);
    try expectEqual(u16, 0x200, cpu.PC());
}

test "Cpu stores value from VY into VX (8XY0)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xB] = 0xBB;

    cpu.store(0xA, 0xB);
    try expectEqual(u8, 0xBB, V[0xA]);
    try expectEqual(u16, 0x1FE, cpu.PC());
}

test "Cpu bitwise ORs VX and VY (8XY1)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 0b0110;
    V[0xB] = 0b1001;
    cpu.bitwiseOr(0xA, 0xB);
    try expectEqual(u8, 0b1111, V[0xA]);
    try expectEqual(u16, 0x1FE, cpu.PC());
}

test "Cpu bitwise ANDs VX and VY (8XY2)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 0b0110;
    V[0xB] = 0b1001;
    cpu.bitwiseAnd(0xA, 0xB);
    try expectEqual(u8, 0b0000, V[0xA]);
    try expectEqual(u16, 0x1FE, cpu.PC());
}

test "Cpu bitwise XORs VX and VY (8XY3)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 0b1010;
    V[0xB] = 0b1001;
    cpu.bitwiseXor(0xA, 0xB);
    try expectEqual(u8, 0b0011, V[0xA]);
    try expectEqual(u16, 0x1FE, cpu.PC());
}

test "Cpu adds registers VX and VY and sets VF if overflow (8XY4)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 0xF0;
    V[0xB] = 0x0A;

    cpu.add(0xA, 0xB);
    try expectEqual(u8, 0xFA, V[0xA]);
    try expectEqual(u8, 0, V[0xF]);
    try expectEqual(u16, 0x1FE, cpu.PC());

    cpu.add(0xA, 0xB);
    try expectEqual(u8, 0x04, V[0xA]);
    try expectEqual(u8, 1, V[0xF]);
    try expectEqual(u16, 0x200, cpu.PC());

    cpu.add(0xA, 0xB);
    try expectEqual(u8, 0xE, V[0xA]);
    try expectEqual(u8, 0, V[0xF]);
    try expectEqual(u16, 0x202, cpu.PC());
}

test "Cpu subs registers VX and VY and sets VF if no underflow (8XY5)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 0x0F;
    V[0xB] = 0x09;

    cpu.sub(0xA, 0xB);
    try expectEqual(u8, 0x06, V[0xA]);
    try expectEqual(u8, 1, V[0xF]);
    try expectEqual(u16, 0x1FE, cpu.PC());

    cpu.sub(0xA, 0xB);
    try expectEqual(u8, 0xFD, V[0xA]);
    try expectEqual(u8, 0, V[0xF]);
    try expectEqual(u16, 0x200, cpu.PC());

    cpu.sub(0xA, 0xB);
    try expectEqual(u8, 0xF4, V[0xA]);
    try expectEqual(u8, 1, V[0xF]);
    try expectEqual(u16, 0x202, cpu.PC());
}

test "Cpu right shifts VY into VX and sets VF to the LSB (8XY6)" {
    var cpu = getTestCpu();

    const V = cpu.registers();

    V[0xA] = 0;
    V[0xB] = 0b1101;

    cpu.shiftRight(0xA, 0xB);
    try expectEqual(u8, 0b0110, V[0xA]);
    try expectEqual(u8, 0b1101, V[0xB]);
    try expectEqual(u8, 1, V[0xF]);
    try expectEqual(u16, 0x1FE, cpu.PC());

    V[0xB] = 0b0010;
    cpu.shiftRight(0xA, 0xB);
    try expectEqual(u8, 0b0001, V[0xA]);
    try expectEqual(u8, 0b0010, V[0xB]);
    try expectEqual(u8, 0, V[0xF]);
    try expectEqual(u16, 0x200, cpu.PC());
}

test "Cpu right shifts VX into itself if quirk is enabled" {
    var memory: [4096]u8 = std.mem.zeroes([4096]u8);
    Loader.initMem(&memory);
    test_keypad = Keypad.init();
    test_sound_timer = Timer.init(0);
    test_delay_timer = Timer.init(0);
    var cpu = Cpu.init(.{ .seed = 0, .memory = &memory, .keypad = &test_keypad, .sound_timer = &test_sound_timer, .delay_timer = &test_delay_timer, .shift_quirk = true, .register_quirk = false });

    const V = cpu.registers();

    V[0xA] = 0b1101;
    V[0xB] = 0b1111;

    cpu.shiftRight(0xA, 0xB);
    try expectEqual(u8, 0b0110, V[0xA]);
    try expectEqual(u8, 0b1111, V[0xB]);
    try expectEqual(u8, 1, V[0xF]);
    try expectEqual(u16, 0x1FE, cpu.PC());

    V[0xA] = 0b0010;
    cpu.shiftRight(0xA, 0xB);
    try expectEqual(u8, 0b0001, V[0xA]);
    try expectEqual(u8, 0b1111, V[0xB]);
    try expectEqual(u8, 0, V[0xF]);
    try expectEqual(u16, 0x200, cpu.PC());
}

test "Cpu sets VX to 'VY - VX' and sets VF if no underflow (8XY7)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 0x09;
    V[0xB] = 0x0A;

    cpu.subStore(0xA, 0xB);
    try expectEqual(u8, 0x01, V[0xA]);
    try expectEqual(u8, 1, V[0xF]);
    try expectEqual(u16, 0x1FE, cpu.PC());

    V[0xA] = 0xC;
    cpu.subStore(0xA, 0xB);
    try expectEqual(u8, 0xFE, V[0xA]);
    try expectEqual(u8, 0, V[0xF]);
    try expectEqual(u16, 0x200, cpu.PC());

    V[0xA] = 0x3;
    cpu.subStore(0xA, 0xB);
    try expectEqual(u8, 0x07, V[0xA]);
    try expectEqual(u8, 1, V[0xF]);
    try expectEqual(u16, 0x202, cpu.PC());
}

test "Cpu left shifts VY into VX and sets VF to the MSB (8XYE)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 0;
    V[0xB] = 0b11011111;

    cpu.shiftLeft(0xA, 0xB);
    try expectEqual(u8, 0b10111110, V[0xA]);
    try expectEqual(u8, 0b11011111, V[0xB]);
    try expectEqual(u8, 1, V[0xF]);
    try expectEqual(u16, 0x1FE, cpu.PC());

    V[0xB] = 0b00101111;
    cpu.shiftLeft(0xA, 0xB);
    try expectEqual(u8, 0b01011110, V[0xA]);
    try expectEqual(u8, 0b00101111, V[0xB]);
    try expectEqual(u8, 0, V[0xF]);
    try expectEqual(u16, 0x200, cpu.PC());
}

test "Cpu left shifts VX into itself if quirk is enabled" {
    var memory: [4096]u8 = std.mem.zeroes([4096]u8);
    Loader.initMem(&memory);
    test_keypad = Keypad.init();
    test_sound_timer = Timer.init(0);
    test_delay_timer = Timer.init(0);
    var cpu = Cpu.init(.{ .seed = 0, .memory = &memory, .keypad = &test_keypad, .sound_timer = &test_sound_timer, .delay_timer = &test_delay_timer, .shift_quirk = true, .register_quirk = false });

    const V = cpu.registers();

    V[0xA] = 0b11011111;
    V[0xB] = 0;

    cpu.shiftLeft(0xA, 0xB);
    try expectEqual(u8, 0b10111110, V[0xA]);
    try expectEqual(u8, 0, V[0xB]);
    try expectEqual(u8, 1, V[0xF]);
    try expectEqual(u16, 0x1FE, cpu.PC());

    V[0xA] = 0b00101111;
    cpu.shiftLeft(0xA, 0xB);
    try expectEqual(u8, 0b01011110, V[0xA]);
    try expectEqual(u8, 0, V[0xB]);
    try expectEqual(u8, 0, V[0xF]);
    try expectEqual(u16, 0x200, cpu.PC());
}

test "Cpu skips if not equal register (9XY0)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 0x5;
    V[0xB] = 0xA;

    cpu.skipIfNotEqual(0xA, 0xB);
    try expectEqual(u16, 0x200, cpu.PC());

    V[0xB] = 0x5;
    cpu.skipIfNotEqual(0xA, 0xB);
    try expectEqual(u16, 0x202, cpu.PC());
}

test "Cpu stores memory address into I (ANNN)" {
    var cpu = getTestCpu();

    cpu.storeAddressI(0x300);
    try expectEqual(u16, 0x300, cpu.I());
    try expectEqual(u16, 0x1FE, cpu.PC());
}

test "Cpu jumps to NNN plus V0 (BNNN)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0] = 0x10;

    cpu.jumpWithOffset(0x400);
    try expectEqual(u16, 0x410, cpu.PC());
}

test "Cpu sets VX to a random number with mask (CXNN)" {
    // Wtih seed 0, the first number is 223 = 0b11011111
    var cpu = getTestCpu();
    const V = cpu.registers();

    cpu.genRandom(0xA, 0b11110000);
    try expectEqual(u8, 0b11010000, V[0xA]);
    try expectEqual(u16, 0x1FE, cpu.PC());
}

test "Cpu draws sprite (DXYN)" {
    var cpu = getTestCpu();
    const V = cpu.registers();
    const s = cpu.displayBuffer();

    // Draw a 0 at (0, 0).
    // No offset, simplest case.
    cpu.setI(0);
    V[0xA] = 0;
    V[0xB] = 0;
    cpu.draw(0xA, 0xB, 5);

    // Draw a 1 at (16, 0).
    // Has X offset at multiple of 8.
    cpu.setI(5);
    V[0xA] = 16;
    V[0xB] = 0;
    cpu.draw(0xA, 0xB, 5);

    // Draw a 2 at (0, 16).
    // Has Y offset at multiple of 8.
    cpu.setI(10);
    V[0xA] = 0;
    V[0xB] = 16;
    cpu.draw(0xA, 0xB, 5);

    // Draw a 3 at (16, 16).
    // Has X and Y offset at multiples of 8.
    cpu.setI(15);
    V[0xA] = 16;
    V[0xB] = 16;
    cpu.draw(0xA, 0xB, 5);

    // Draw a 5 at (25, 0).
    // Has X and Y offsets, but X is not a multiple of 8
    cpu.setI(25);
    V[0xA] = 25;
    V[0xB] = 0;
    cpu.draw(0xA, 0xB, 5);

    // Draw a 9 at (30, 16).
    // Has X and Y offsets, neither of which are multiples of X
    // The drawing spans 2 separate bytes
    cpu.setI(45);
    V[0xA] = 30;
    V[0xB] = 16;
    cpu.draw(0xA, 0xB, 5);

    // Draw a 7 at (62, 8).
    // This drawing wraps around the X axis.
    cpu.setI(35);
    V[0xA] = 62;
    V[0xB] = 8;
    cpu.draw(0xA, 0xB, 5);

    // Draw a 8 at (8, 30).
    // This drawing wraps around the Y axis.
    cpu.setI(40);
    V[0xA] = 8;
    V[0xB] = 30;
    cpu.draw(0xA, 0xB, 5);

    // var i: usize = 0;
    // while (i < 32) : (i += 1) {
    //     print("\n{b:0>8}", .{s[8 * i .. 8 * (i + 1)]});
    // }

    // 0xF0, 0x90, 0x90, 0x90, 0xF0 // 0
    try expectEqual(u8, 0xF0, s[0]);
    try expectEqual(u8, 0x90, s[8]);
    try expectEqual(u8, 0x90, s[16]);
    try expectEqual(u8, 0x90, s[24]);
    try expectEqual(u8, 0xF0, s[32]);

    // 0x20, 0x60, 0x20, 0x20, 0x70 // 1
    try expectEqual(u8, 0x20, s[2]);
    try expectEqual(u8, 0x60, s[10]);
    try expectEqual(u8, 0x20, s[18]);
    try expectEqual(u8, 0x20, s[26]);
    try expectEqual(u8, 0x70, s[34]);

    // 0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    try expectEqual(u8, 0xF0, s[128]);
    try expectEqual(u8, 0x10, s[136]);
    try expectEqual(u8, 0xF0, s[144]);
    try expectEqual(u8, 0x80, s[152]);
    try expectEqual(u8, 0xF0, s[160]);

    // 0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    try expectEqual(u8, 0xF0, s[130]);
    try expectEqual(u8, 0x10, s[138]);
    try expectEqual(u8, 0xF0, s[146]);
    try expectEqual(u8, 0x10, s[154]);
    try expectEqual(u8, 0xF0, s[162]);

    // 0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    try expectEqual(u8, 0x78, s[3]);
    try expectEqual(u8, 0x40, s[11]);
    try expectEqual(u8, 0x78, s[19]);
    try expectEqual(u8, 0x08, s[27]);
    try expectEqual(u8, 0x78, s[35]);

    // 0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    try expectEqual(u8, 0x03, s[131]);
    try expectEqual(u8, 0xC0, s[132]);
    try expectEqual(u8, 0x02, s[139]);
    try expectEqual(u8, 0x40, s[140]);
    try expectEqual(u8, 0x03, s[147]);
    try expectEqual(u8, 0xC0, s[148]);
    try expectEqual(u8, 0x00, s[155]);
    try expectEqual(u8, 0x40, s[156]);
    try expectEqual(u8, 0x03, s[163]);
    try expectEqual(u8, 0xC0, s[164]);

    // 0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    try expectEqual(u8, 0xC0, s[64]);
    try expectEqual(u8, 0x03, s[71]);
    try expectEqual(u8, 0x40, s[72]);
    try expectEqual(u8, 0x00, s[79]);
    try expectEqual(u8, 0x80, s[80]);
    try expectEqual(u8, 0x00, s[87]);
    try expectEqual(u8, 0x00, s[88]);
    try expectEqual(u8, 0x01, s[95]);
    try expectEqual(u8, 0x00, s[96]);
    try expectEqual(u8, 0x01, s[103]);

    // 0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    try expectEqual(u8, 0xF0, s[1]);
    try expectEqual(u8, 0x90, s[9]);
    try expectEqual(u8, 0xF0, s[17]);
    try expectEqual(u8, 0xF0, s[241]);
    try expectEqual(u8, 0x90, s[249]);
    try expectEqual(u16, 0x20C, cpu.PC());
}

test "Cpu sets VF if drawing erases any pixels" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    cpu.setI(0);
    V[0xF] = 1;

    // Draw unsets VF if no collisions happen
    cpu.draw(0xA, 0xB, 5);
    try expectEqual(u8, 0, V[0xF]);

    // Draw sets VF since a collision happened
    V[0xB] = 4;
    cpu.draw(0xA, 0xB, 5);
    try expectEqual(u8, 1, V[0xF]);
}

test "splitMask helper splits masks correctly" {
    var res = Cpu.splitMask(0b10101111, 4);
    try expectEqual(u8, 0b1010, res.left);
    try expectEqual(u8, 0b11110000, res.right);

    res = Cpu.splitMask(0b01001101, 2);
    try expectEqual(u8, 0b00010011, res.left);
    try expectEqual(u8, 0b01000000, res.right);

    res = Cpu.splitMask(0b11001101, 3);
    try expectEqual(u8, 0b00011001, res.left);
    try expectEqual(u8, 0b10100000, res.right);
}

test "Cpu skips next instruction if key in VX is pressed (EX9E)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    test_keypad.pressKey(7);

    V[0xA] = 7;
    cpu.skipIfPressed(0xA);
    try expectEqual(u16, 0x200, cpu.PC());

    V[0xA] = 8;
    cpu.skipIfPressed(0xA);
    try expectEqual(u16, 0x202, cpu.PC());
}

test "Cpu skips next instruction f key in VX is not pressed (EXA1)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    test_keypad.pressKey(7);

    V[0xA] = 7;
    cpu.skipIfNotPressed(0xA);
    try expectEqual(u16, 0x1FE, cpu.PC());

    V[0xA] = 8;
    cpu.skipIfNotPressed(0xA);
    try expectEqual(u16, 0x202, cpu.PC());
}

test "Cpu stores the value of the delay timer in VX (FX07)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    cpu.delay_timer.value = 10;
    cpu.storeDelayTimer(0xA);
    try expectEqual(u8, 10, V[0xA]);
    try expectEqual(u16, 0x1FE, cpu.PC());
}

test "Cpu waits for keypress and stores result in VX (FX0A)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    var frame = async cpu.waitForKeypress(0xA);
    cpu.keypad.pressKey(5);
    cpu.keypad.releaseKey(5);
    nosuspend await frame;
    try expectEqual(u8, 5, V[0xA]);
    try expectEqual(u16, 0x1FE, cpu.PC());

    frame = async cpu.waitForKeypress(0xC);
    cpu.keypad.pressKey(5);
    cpu.keypad.pressKey(6);
    cpu.keypad.pressKey(7);
    cpu.keypad.releaseKey(6);
    nosuspend await frame;

    try expectEqual(u8, 6, V[0xC]);
    try expectEqual(u16, 0x200, cpu.PC());
}

test "Cpu sets delay timer to value found in VX (FX15)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 10;
    cpu.setDelayTimer(0xA);
    try expectEqual(u8, 10, cpu.delay_timer.value);
    try expectEqual(u16, 0x1FE, cpu.PC());
}

test "Cpu sets sound timer to value found in VX (FX18)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 10;
    cpu.setSoundTimer(0xA);
    try expectEqual(u8, 10, cpu.sound_timer.value);
    try expectEqual(u16, 0x1FE, cpu.PC());

    // Setting the sound timer to values below 2 has no effect
    V[0xA] = 1;
    cpu.setSoundTimer(0xA);
    try expectEqual(u8, 0, cpu.sound_timer.value);
    try expectEqual(u16, 0x200, cpu.PC());
}

test "Cpu adds the value from VX into I (FX1E)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 5;
    cpu.setI(10);

    cpu.addI(0xA);
    try expectEqual(u16, 15, cpu.I());
    try expectEqual(u16, 0x1FE, cpu.PC());
}

test "Cpu sets I to sprite found in VX (FX29)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 5;
    cpu.setSprite(0xA);
    try expectEqual(u16, 25, cpu.I());
    try expectEqual(u16, 0x1FE, cpu.PC());
}

test "Cpu stores BCD of value in VX at I (FX33)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 123;
    cpu.setI(0x500);

    cpu.setBcd(0xA);

    try expectEqual(u8, 1, cpu.mem[0x500]);
    try expectEqual(u8, 2, cpu.mem[0x501]);
    try expectEqual(u8, 3, cpu.mem[0x502]);
    try expectEqual(u16, 0x1FE, cpu.PC());
}

test "Cpu dumps register into memory I (FX55)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    var i: u8 = 0;
    while (i < 16) : (i += 1) {
        V[i] = i;
    }

    cpu.setI(0x500);
    cpu.dumpRegisters(5);

    i = 0;
    while (i < 16) : (i += 1) {
        if (i <= 5) {
            try expectEqual(u8, i, cpu.mem[0x500 + @as(usize, i)]);
        } else {
            try expectEqual(u8, 0, cpu.mem[0x500 + @as(usize, i)]);
        }
    }

    try expectEqual(u16, 0x500 + 5 + 1, cpu.I());
    try expectEqual(u16, 0x1FE, cpu.PC());
}

test "Cpu dumps registers into memory but doesn't touch I if quirk is enabled" {
    var memory: [4096]u8 = std.mem.zeroes([4096]u8);
    Loader.initMem(&memory);
    test_keypad = Keypad.init();
    test_sound_timer = Timer.init(0);
    test_delay_timer = Timer.init(0);
    var cpu = Cpu.init(.{ .seed = 0, .memory = &memory, .keypad = &test_keypad, .sound_timer = &test_sound_timer, .delay_timer = &test_delay_timer, .shift_quirk = false, .register_quirk = true });
    const V = cpu.registers();

    var i: u8 = 0;
    while (i < 16) : (i += 1) {
        V[i] = i;
    }

    cpu.setI(0x500);
    cpu.dumpRegisters(5);

    i = 0;
    while (i < 16) : (i += 1) {
        if (i <= 5) {
            try expectEqual(u8, i, cpu.mem[0x500 + @as(usize, i)]);
        } else {
            try expectEqual(u8, 0, cpu.mem[0x500 + @as(usize, i)]);
        }
    }

    try expectEqual(u16, 0x500, cpu.I());
    try expectEqual(u16, 0x1FE, cpu.PC());
}

test "Cpu restores registers from memory I (FX65)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    var i: u8 = 0;
    while (i < 16) : (i += 1) {
        cpu.mem[0x500 + @as(usize, i)] = i;
    }

    cpu.setI(0x500);
    cpu.restoreRegisters(5);

    while (i < 16) : (i += 1) {
        if (i <= 5) {
            try expectEqual(u8, i, V[i]);
        } else {
            try expectEqual(u8, 0, V[i]);
        }
    }

    try expectEqual(u16, 0x500 + 5 + 1, cpu.I());
    try expectEqual(u16, 0x1FE, cpu.PC());
}

test "Cpu restores registers from memory I but doesn't touch I if quirk is enabled" {
    var memory: [4096]u8 = std.mem.zeroes([4096]u8);
    Loader.initMem(&memory);
    test_keypad = Keypad.init();
    test_sound_timer = Timer.init(0);
    test_delay_timer = Timer.init(0);
    var cpu = Cpu.init(.{ .seed = 0, .memory = &memory, .keypad = &test_keypad, .sound_timer = &test_sound_timer, .delay_timer = &test_delay_timer, .shift_quirk = false, .register_quirk = true });
    const V = cpu.registers();

    var i: u8 = 0;
    while (i < 16) : (i += 1) {
        cpu.mem[0x500 + @as(usize, i)] = i;
    }

    cpu.setI(0x500);
    cpu.restoreRegisters(5);

    while (i < 16) : (i += 1) {
        if (i <= 5) {
            try expectEqual(u8, i, V[i]);
        } else {
            try expectEqual(u8, 0, V[i]);
        }
    }

    try expectEqual(u16, 0x500, cpu.I());
    try expectEqual(u16, 0x1FE, cpu.PC());
}

test "decode extracts bits correctly" {
    var cpu = getTestCpu();
    cpu.setWord(0x200, 0xABCD);
    const decoded = cpu.fetchDecode(0x200);

    try expectEqual(u8, 0xA, decoded.a);
    try expectEqual(u8, 0xB, decoded.b);
    try expectEqual(u8, 0xC, decoded.c);
    try expectEqual(u8, 0xD, decoded.d);
    try expectEqual(u16, 0xBCD, decoded.nnn);
}
