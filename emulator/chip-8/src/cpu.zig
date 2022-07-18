const std = @import("std");
const Keypad = @import("./keypad.zig").Keypad;
const Timer = @import("./timer.zig").Timer;
const wasm = @import("./wasm.zig");
const fmt = std.fmt;
const rand = std.rand;
const panic = @import("./util.zig").panic;

const CpuOptions = struct {
    memory: [4096]u8,
    keypad: *Keypad,
    sound_timer: *Timer,
    delay_timer: *Timer,
    seed: u64,
};

pub const Cpu = struct {
    const MEM_SIZE = 4096;

    // Memory
    mem: [MEM_SIZE]u8,

    // Special Registers
    I: u16 = 0,
    PC: u16 = 0x200,
    SP: u16 = 0xECF,

    // Helpers
    keypad: *Keypad,
    sound_timer: *Timer,
    delay_timer: *Timer,
    rand: rand.Random,

    const Self = @This();

    pub fn init(options: CpuOptions) Self {
        var prng = rand.DefaultPrng.init(options.seed);
        const random = prng.random();

        return Self{ .mem = options.memory, .rand = random, .keypad = options.keypad, .sound_timer = options.sound_timer, .delay_timer = options.delay_timer };
    }

    pub inline fn display_buffer(self: *Self) *[256]u8 {
        return self.mem[MEM_SIZE - 256 ..];
    }

    inline fn stackPush(self: *Self, address: u16) void {
        // Chip-8 is big endian, so the most significant byte goes in a lower memory address
        self.mem[self.SP - 1] = @truncate(u8, @shrExact(address & 0xFF00, 8));
        self.mem[self.SP] = @truncate(u8, address);
        self.SP -= 2;
    }

    inline fn stackPop(self: *Self) u16 {
        // Chip-8 is big endian, so the most significant byte goes in a lower memory address
        const msb = @as(u16, self.mem[self.SP + 1]);
        const lsb = self.mem[self.SP + 2];
        self.SP += 2;
        return @shlExact(msb, 8) + lsb;
    }

    inline fn stackPeek(self: *Self) u16 {
        // SP always points to next available position, so SP+1 contains the top of the stack
        // (remember, stacks grow downwards)
        const msb = @as(u16, self.mem[self.SP + 1]);
        const lsb = self.mem[self.SP + 2];
        return @shlExact(msb, 8) + lsb;
    }

    inline fn registers(self: *Self) *[16]u8 {
        return self.mem[0xEF0..0xF00];
    }

    pub fn fetchDecodeExecute(self: *Self) void {
        const first = self.mem[self.PC];
        const second = self.mem[self.PC + 1];

        const a: u4 = @truncate(u4, @shrExact(first & 0xF0, 4));
        const b: u4 = @truncate(u4, first);
        const c: u4 = @truncate(u4, @shrExact(second & 0xF0, 4));
        const d: u4 = @truncate(u4, second);

        const nnn: u16 = @shlExact(@as(u16, b), 8) + second;
        const instruction: [2]u8 = [_]u8{ first, second };
        wasm.log("fetched {}", .{fmt.fmtSliceHexUpper(&instruction)});
        wasm.log("PC: {}", .{self.PC});

        switch (a) {
            0 => {
                switch (second) {
                    0xE0 => self.clearScreen(),
                    0xEE => self.returnFromSubroutine(),
                    else => self.syscall(nnn) catch |err| {
                        panic("syscall error: {}", .{err});
                    },
                }
            },
            1 => self.jump(nnn),
            2 => self.callSubroutine(nnn),
            3 => self.skipIfEqualLiteral(b, second),
            4 => self.skipIfNotEqualLiteral(b, second),
            5 => self.skipIfEqual(b, c),
            6 => self.storeLiteral(b, second),
            7 => self.addLiteral(b, second),
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
                    else => panic("unknown instruction: {}", .{fmt.fmtSliceHexUpper(self.mem[self.PC .. self.PC + 2])}),
                }
            },
            9 => self.skipIfNotEqual(b, c),
            0xA => self.storeAddress(nnn),
            0xB => self.jumpWithOffset(nnn),
            0xC => self.genRandom(b, second),
            0xD => self.draw(b, c, d),
            0xE => {
                switch (second) {
                    0x9E => self.skipIfPressed(b),
                    0xA1 => self.skipIfNotPressed(b),
                    else => panic("unknown instruction: {}", .{fmt.fmtSliceHexUpper(self.mem[self.PC .. self.PC + 2])}),
                }
            },
            0xF => {
                switch (second) {
                    0x07 => self.storeDelayTimer(b),
                    0x0A => self.waitForKeypress(b),
                    0x15 => self.setDelayTimer(b),
                    0x18 => self.setSoundTimer(b),
                    0x1E => self.addToI(b),
                    0x29 => self.setSprite(b),
                    0x33 => self.setBcd(b),
                    0x55 => self.dumpRegisters(b),
                    0x65 => self.restoreRegisters(b),
                    else => panic("unknown instruction: {}", .{fmt.fmtSliceHexUpper(self.mem[self.PC .. self.PC + 2])}),
                }
            },
        }

        wasm.log("PC: {}", .{self.PC});
    }

    // Instructions

    pub fn syscall(self: *Self, code: u16) !void {
        _ = self;
        _ = code;
        return error.NotImplemented;
    }

    pub fn callSubroutine(self: *Self, address: u16) void {
        self.stackPush(self.PC);
        self.PC = address;
    }

    pub fn clearScreen(self: *Self) void {
        for (self.display_buffer()) |*b| {
            b.* = 0;
        }
        self.PC += 2;
    }

    pub fn returnFromSubroutine(self: *Self) void {
        self.PC = self.stackPop();
    }

    pub fn jump(self: *Self, address: u16) void {
        self.PC = address;
    }

    pub fn skipIfEqualLiteral(self: *Self, register: u4, value: u8) void {
        const V = self.registers();
        if (V[register] == value) {
            self.PC += 2;
        }
        self.PC += 2;
    }

    pub fn skipIfNotEqualLiteral(self: *Self, register: u4, value: u8) void {
        const V = self.registers();
        if (V[register] != value) {
            self.PC += 2;
        }
        self.PC += 2;
    }

    pub fn skipIfEqual(self: *Self, registerX: u4, registerY: u4) void {
        const V = self.registers();
        if (V[registerX] == V[registerY]) {
            self.PC += 2;
        }
        self.PC += 2;
    }

    pub fn storeLiteral(self: *Self, register: u4, value: u8) void {
        const V = self.registers();
        V[register] = value;
        self.PC += 2;
    }

    pub fn addLiteral(self: *Self, register: u4, value: u8) void {
        const V = self.registers();
        V[register] +%= value;
        self.PC += 2;
    }

    pub fn store(self: *Self, registerX: u4, registerY: u4) void {
        const V = self.registers();
        V[registerX] = V[registerY];
        self.PC += 2;
    }

    pub fn bitwiseOr(self: *Self, registerX: u4, registerY: u4) void {
        const V = self.registers();
        V[registerX] |= V[registerY];
        self.PC += 2;
    }

    pub fn bitwiseAnd(self: *Self, registerX: u4, registerY: u4) void {
        const V = self.registers();
        V[registerX] &= V[registerY];
        self.PC += 2;
    }

    pub fn bitwiseXor(self: *Self, registerX: u4, registerY: u4) void {
        const V = self.registers();
        V[registerX] ^= V[registerY];
        self.PC += 2;
    }

    pub fn add(self: *Self, registerX: u4, registerY: u4) void {
        const V = self.registers();
        const overflow = @addWithOverflow(u8, V[registerX], V[registerY], &V[registerX]);
        V[0xF] = @boolToInt(overflow);
        self.PC += 2;
    }

    pub fn sub(self: *Self, registerX: u4, registerY: u4) void {
        const V = self.registers();
        const underflow = @subWithOverflow(u8, V[registerX], V[registerY], &V[registerX]);
        V[0xF] = @boolToInt(!underflow);
        self.PC += 2;
    }

    pub fn shiftRight(self: *Self, registerX: u4, registerY: u4) void {
        const V = self.registers();
        V[registerX] = V[registerY] >> 1;
        V[0xF] = V[registerY] & 1;
        self.PC += 2;
    }

    pub fn subStore(self: *Self, registerX: u4, registerY: u4) void {
        const V = self.registers();
        const underflow = @subWithOverflow(u8, V[registerY], V[registerX], &V[registerX]);
        V[0xF] = @boolToInt(!underflow);
        self.PC += 2;
    }

    // TODO: Implement VF setting alternative behaviour
    pub fn shiftLeft(self: *Self, registerX: u4, registerY: u4) void {
        const V = self.registers();
        const overflow = @shlWithOverflow(u8, V[registerY], 1, &V[registerX]);
        V[0xF] = @boolToInt(overflow);
        self.PC += 2;
    }

    pub fn skipIfNotEqual(self: *Self, registerX: u4, registerY: u4) void {
        const V = self.registers();
        if (V[registerX] != V[registerY]) {
            self.PC += 2;
        }
        self.PC += 2;
    }

    pub fn storeAddress(self: *Self, address: u16) void {
        self.I = address;
        self.PC += 2;
    }

    pub fn jumpWithOffset(self: *Self, address: u16) void {
        const V = self.registers();
        self.PC = V[0] + address;
    }

    pub fn genRandom(self: *Self, register: u4, mask: u8) void {
        const V = self.registers();
        V[register] = self.rand.int(u8) & mask;
        self.PC += 2;
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
    pub fn draw(self: *Self, X: u6, Y: u5, height: u8) void {
        const V = self.registers();
        const y = @intCast(u8, @mod(@as(usize, Y) * 8, 256)); // 31*8=248 at most
        const _x: usize = X;
        // In most situations, drawing something on the screen will require applying a mask to two differente bytes
        // Looking at X + 8 (with modulo) guarantees that we look at the next byte in the row (wrapped if needed).
        // But we don't want the next byte if X is exactly divisible by 8 since the mask is supposed to only affect one byte,
        // in such situations, so we use X + 7 instead.
        // This guarantees that we grab the next byte if and only if X is not divisible by 8.
        const x_first = @mod(_x, 64) / 8; // 7 at most
        const x_second = @mod(_x + 7, 64) / 8; // 7 at most
        const bits_first = @intCast(u3, @mod(@mod(_x, 64), 8)); // 0-7
        const display = self.display_buffer();
        V[0xF] = 0;
        var i: usize = 0;
        while (i < height) : (i += 1) {
            const offset = 8 * i;
            const sprite_data = self.mem[self.I + i];
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
            self.PC += 2;
        }
        self.PC += 2;
    }

    pub fn skipIfNotPressed(self: *Self, register: u4) void {
        const V = self.registers();
        const key = @intCast(u4, V[register]);
        if (!self.keypad.isPressed(key)) {
            self.PC += 2;
        }
        self.PC += 2;
    }

    pub fn storeDelayTimer(self: *Self, register: u4) void {
        const V = self.registers();
        V[register] = self.delay_timer.value;
        self.PC += 2;
    }

    pub fn waitForKeypress(self: *Self, register: u4) void {
        const key = await async self.keypad.waitForKeypress();
        const V = self.registers();
        V[register] = key;
        self.PC += 2;
    }

    pub fn setDelayTimer(self: *Self, register: u4) void {
        const V = self.registers();
        self.delay_timer.set(V[register]);
        self.PC += 2;
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
        self.PC += 2;
    }

    pub fn addToI(self: *Self, register: u4) void {
        const V = self.registers();
        self.I += V[register];
        self.PC += 2;
    }

    pub fn setSprite(self: *Self, register: u4) void {
        const V = self.registers();
        self.I = V[register] * 5;
        self.PC += 2;
    }

    pub fn setBcd(self: *Self, register: u4) void {
        const V = self.registers();
        const val = V[register];
        self.mem[self.I] = val / 100;
        self.mem[self.I + 1] = @mod(val, 100) / 10;
        self.mem[self.I + 2] = @mod(val, 10);
        self.PC += 2;
    }

    // TODO: implement flag to switch to buggy spec
    pub fn dumpRegisters(self: *Self, register: u4) void {
        const V = self.registers();
        var i: usize = 0;
        while (i <= register) {
            self.mem[self.I] = V[i];
            i += 1;
            self.I += 1;
        }
        self.PC += 2;
    }

    pub fn restoreRegisters(self: *Self, register: u4) void {
        const V = self.registers();
        var i: usize = 0;
        while (i <= register) {
            V[i] = self.mem[self.I];
            i += 1;
            self.I += 1;
        }
        self.PC += 2;
    }
};

// Tests

const expect = std.testing.expect;
const expectError = std.testing.expectError;
const print = std.debug.print;
const Loader = @import("./loader.zig").Loader;

var test_keypad: Keypad = undefined;
var test_sound_timer: Timer = undefined;
var test_delay_timer: Timer = undefined;

fn getTestCpu() Cpu {
    var memory: [4096]u8 = std.mem.zeroes([4096]u8);
    Loader.loadFonts(&memory);
    test_keypad = Keypad.init();
    test_sound_timer = Timer.init(0);
    test_delay_timer = Timer.init(0);
    return Cpu.init(.{ .seed = 0, .memory = memory, .keypad = &test_keypad, .sound_timer = &test_sound_timer, .delay_timer = &test_delay_timer });
}

test "Cpu makes syscall (0NNN)" {
    var cpu = getTestCpu();
    try expectError(error.NotImplemented, cpu.syscall(0x300));
}

test "Cpu clears screens (00E0)" {
    var cpu = getTestCpu();
    for (cpu.display_buffer()) |*b, i| {
        b.* = @intCast(u8, i);
    }

    cpu.clearScreen();
    for (cpu.display_buffer()) |b| {
        try expect(b == 0);
    }
    try expect(cpu.PC == 0x202);
}

test "Cpu returns from subroutine (00EE)" {
    var cpu = getTestCpu();
    cpu.stackPush(0x500);
    cpu.stackPush(0x800);

    cpu.returnFromSubroutine();
    try expect(cpu.SP == 0xECD);
    try expect(cpu.PC == 0x800);

    cpu.returnFromSubroutine();
    try expect(cpu.SP == 0xECF);
    try expect(cpu.PC == 0x500);
}

test "Cpu jumps to address (1NNN)" {
    var cpu = getTestCpu();

    cpu.jump(0x300);
    try expect(cpu.PC == 0x300);

    cpu.jump(0x500);
    try expect(cpu.PC == 0x500);
}

test "Cpu calls subroutine (2NNN)" {
    var cpu = getTestCpu();

    cpu.callSubroutine(0x300);
    try expect(cpu.PC == 0x300);
    try expect(cpu.SP == 0xECD);
    try expect(cpu.stackPeek() == 0x200);

    cpu.callSubroutine(0x500);
    try expect(cpu.PC == 0x500);
    try expect(cpu.SP == 0xECB);
    try expect(cpu.stackPeek() == 0x300);
}

test "Cpu skips next instruction if VX equals literal (3XNN)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 0xFF;

    cpu.skipIfEqualLiteral(0xA, 0xFF);
    try expect(cpu.PC == 0x204);

    cpu.skipIfEqualLiteral(0xA, 0xAB);
    try expect(cpu.PC == 0x206);
}

test "Cpu skips next instruction if VX not equals literal (4XNN)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 0xFF;

    cpu.skipIfNotEqualLiteral(0xA, 0xBC);
    try expect(cpu.PC == 0x204);

    cpu.skipIfNotEqualLiteral(0xA, 0xFF);
    try expect(cpu.PC == 0x206);
}

test "Cpu skips next instruction if VX equals VY (5XY0)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 0xFF;
    V[0xB] = 0xFF;

    cpu.skipIfEqual(0xA, 0xB);
    try expect(cpu.PC == 0x204);

    V[0xB] = 0x21;

    cpu.skipIfEqual(0xA, 0xB);
    try expect(cpu.PC == 0x206);
}

test "Cpu stores literal into register (6XNN)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    cpu.storeLiteral(0xA, 0xFF);
    try expect(V[0xA] == 0xFF);
    try expect(cpu.PC == 0x202);

    cpu.storeLiteral(0xC, 0xCC);
    try expect(V[0xC] == 0xCC);
    try expect(cpu.PC == 0x204);
}

test "Cpu adds literal into register (7XNN)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    cpu.addLiteral(0xA, 0xFA);
    try expect(V[0xA] == 0xFA);
    try expect(cpu.PC == 0x202);

    // Overflows
    cpu.addLiteral(0xA, 0x06);
    try expect(V[0xA] == 0x00);
    try expect(cpu.PC == 0x204);
}

test "Cpu stores value from VY into VX (8XY0)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xB] = 0xBB;

    cpu.store(0xA, 0xB);
    try expect(V[0xA] == 0xBB);
    try expect(cpu.PC == 0x202);
}

test "Cpu bitwise ORs VX and VY (8XY1)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 0b0110;
    V[0xB] = 0b1001;
    cpu.bitwiseOr(0xA, 0xB);
    try expect(V[0xA] == 0b1111);
    try expect(cpu.PC == 0x202);
}

test "Cpu bitwise ANDs VX and VY (8XY2)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 0b0110;
    V[0xB] = 0b1001;
    cpu.bitwiseAnd(0xA, 0xB);
    try expect(V[0xA] == 0b0000);
    try expect(cpu.PC == 0x202);
}

test "Cpu bitwise XORs VX and VY (8XY3)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 0b1010;
    V[0xB] = 0b1001;
    cpu.bitwiseXor(0xA, 0xB);
    try expect(V[0xA] == 0b0011);
    try expect(cpu.PC == 0x202);
}

test "Cpu adds registers VX and VY and sets VF if overflow (8XY4)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 0xF0;
    V[0xB] = 0x0A;

    cpu.add(0xA, 0xB);
    try expect(V[0xA] == 0xFA);
    try expect(V[0xF] == 0);
    try expect(cpu.PC == 0x202);

    cpu.add(0xA, 0xB);
    try expect(V[0xA] == 0x04);
    try expect(V[0xF] == 1);
    try expect(cpu.PC == 0x204);

    cpu.add(0xA, 0xB);
    try expect(V[0xA] == 0xE);
    try expect(V[0xF] == 0);
    try expect(cpu.PC == 0x206);
}

test "Cpu subs registers VX and VY and sets VF if no underflow (8XY5)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 0x0F;
    V[0xB] = 0x09;

    cpu.sub(0xA, 0xB);
    try expect(V[0xA] == 0x06);
    try expect(V[0xF] == 1);
    try expect(cpu.PC == 0x202);

    cpu.sub(0xA, 0xB);
    try expect(V[0xA] == 0xFD);
    try expect(V[0xF] == 0);
    try expect(cpu.PC == 0x204);

    cpu.sub(0xA, 0xB);
    try expect(V[0xA] == 0xF4);
    try expect(V[0xF] == 1);
    try expect(cpu.PC == 0x206);
}

test "Cpu right shifts VY into VX and sets VF to the LSB (8XY6)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 0;
    V[0xB] = 0b1101;

    cpu.shiftRight(0xA, 0xB);
    try expect(V[0xA] == 0b0110);
    try expect(V[0xB] == 0b1101);
    try expect(V[0xF] == 1);
    try expect(cpu.PC == 0x202);

    V[0xB] = 0b0010;
    cpu.shiftRight(0xA, 0xB);
    try expect(V[0xA] == 0b0001);
    try expect(V[0xB] == 0b0010);
    try expect(V[0xF] == 0);
    try expect(cpu.PC == 0x204);
}

test "Cpu sets VX to 'VY - VX' and sets VF if no underflow (8XY7)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 0x09;
    V[0xB] = 0x0A;

    cpu.subStore(0xA, 0xB);
    try expect(V[0xA] == 0x01);
    try expect(V[0xF] == 1);
    try expect(cpu.PC == 0x202);

    V[0xA] = 0xC;
    cpu.subStore(0xA, 0xB);
    try expect(V[0xA] == 0xFE);
    try expect(V[0xF] == 0);
    try expect(cpu.PC == 0x204);

    V[0xA] = 0x3;
    cpu.subStore(0xA, 0xB);
    try expect(V[0xA] == 0x07);
    try expect(V[0xF] == 1);
    try expect(cpu.PC == 0x206);
}

test "Cpu left shifts VY into VX and sets VF to the MSB (8XYE)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 0;
    V[0xB] = 0b11011111;

    cpu.shiftLeft(0xA, 0xB);
    try expect(V[0xA] == 0b10111110);
    try expect(V[0xB] == 0b11011111);
    try expect(V[0xF] == 1);
    try expect(cpu.PC == 0x202);

    V[0xB] = 0b00101111;
    cpu.shiftLeft(0xA, 0xB);
    try expect(V[0xA] == 0b01011110);
    try expect(V[0xB] == 0b00101111);
    try expect(V[0xF] == 0);
    try expect(cpu.PC == 0x204);
}

test "Cpu skips if not equal register (9XY0)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 0x5;
    V[0xB] = 0xA;

    cpu.skipIfNotEqual(0xA, 0xB);
    try expect(cpu.PC == 0x204);

    V[0xB] = 0x5;
    cpu.skipIfNotEqual(0xA, 0xB);
    try expect(cpu.PC == 0x206);
}

test "Cpu stores memory address into I (ANNN)" {
    var cpu = getTestCpu();

    cpu.storeAddress(0x300);
    try expect(cpu.I == 0x300);
    try expect(cpu.PC == 0x202);
}

test "Cpu jumps to NNN plus V0 (BNNN)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0] = 0x10;

    cpu.jumpWithOffset(0x400);
    try expect(cpu.PC == 0x410);
}

test "Cpu sets VX to a random number with mask (CXNN)" {
    // Wtih seed 0, the first number is 223 = 0b11011111
    var cpu = getTestCpu();
    const V = cpu.registers();

    cpu.genRandom(0xA, 0b11110000);
    try expect(V[0xA] == 0b11010000);
    try expect(cpu.PC == 0x202);
}

test "Cpu draws sprite (DXYN)" {
    var cpu = getTestCpu();
    const s = cpu.display_buffer();

    // Draw a 0 at (0, 0).
    // No offset, simplest case.
    cpu.I = 0;
    cpu.draw(0, 0, 5);

    // Draw a 1 at (16, 0).
    // Has X offset at multiple of 8.
    cpu.I = 5;
    cpu.draw(16, 0, 5);

    // Draw a 2 at (0, 16).
    // Has Y offset at multiple of 8.
    cpu.I = 10;
    cpu.draw(0, 16, 5);

    // Draw a 3 at (16, 16).
    // Has X and Y offset at multiples of 8.
    cpu.I = 15;
    cpu.draw(16, 16, 5);

    // Draw a 5 at (26, 0).
    // Has X and Y offsets, but X is not a multiple of 8
    cpu.I = 25;
    cpu.draw(25, 0, 5);

    // Draw a 9 at (31, 16).
    // Has X and Y offsets, neither of which are multiples of X
    // The drawing spans 2 separate bytes
    cpu.I = 45;
    cpu.draw(30, 16, 5);

    // Draw a 7 at (63, 8).
    // This drawing wraps around the X axis.
    cpu.I = 35;
    cpu.draw(62, 8, 5);

    // Draw a 8 at (8, 30).
    // This drawing wraps around the Y axis.
    cpu.I = 40;
    cpu.draw(8, 30, 5);

    // var i: usize = 0;
    // while (i < 32) : (i += 1) {
    //     print("\n{b:0>8}", .{s[8 * i .. 8 * (i + 1)]});
    // }

    // 0xF0, 0x90, 0x90, 0x90, 0xF0 // 0
    try expect(s[0] == 0xF0);
    try expect(s[8] == 0x90);
    try expect(s[16] == 0x90);
    try expect(s[24] == 0x90);
    try expect(s[32] == 0xF0);

    // 0x20, 0x60, 0x20, 0x20, 0x70 // 1
    try expect(s[2] == 0x20);
    try expect(s[10] == 0x60);
    try expect(s[18] == 0x20);
    try expect(s[26] == 0x20);
    try expect(s[34] == 0x70);

    // 0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    try expect(s[128] == 0xF0);
    try expect(s[136] == 0x10);
    try expect(s[144] == 0xF0);
    try expect(s[152] == 0x80);
    try expect(s[160] == 0xF0);

    // 0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    try expect(s[130] == 0xF0);
    try expect(s[138] == 0x10);
    try expect(s[146] == 0xF0);
    try expect(s[154] == 0x10);
    try expect(s[162] == 0xF0);

    // 0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    try expect(s[3] == 0x78);
    try expect(s[11] == 0x40);
    try expect(s[19] == 0x78);
    try expect(s[27] == 0x08);
    try expect(s[35] == 0x78);

    // 0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    try expect(s[131] == 0x03);
    try expect(s[132] == 0xC0);
    try expect(s[139] == 0x02);
    try expect(s[140] == 0x40);
    try expect(s[147] == 0x03);
    try expect(s[148] == 0xC0);
    try expect(s[155] == 0x00);
    try expect(s[156] == 0x40);
    try expect(s[163] == 0x03);
    try expect(s[164] == 0xC0);

    // 0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    try expect(s[64] == 0xC0);
    try expect(s[71] == 0x03);
    try expect(s[72] == 0x40);
    try expect(s[79] == 0x00);
    try expect(s[80] == 0x80);
    try expect(s[87] == 0x00);
    try expect(s[88] == 0x00);
    try expect(s[95] == 0x01);
    try expect(s[96] == 0x00);
    try expect(s[103] == 0x01);

    // 0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    try expect(s[1] == 0xF0);
    try expect(s[9] == 0x90);
    try expect(s[17] == 0xF0);
    try expect(s[241] == 0xF0);
    try expect(s[249] == 0x90);
}

test "Cpu sets VF if drawing erases any pixels" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    cpu.I = 0;
    V[0xF] = 1;

    // Draw unsets VF if no collisions happen
    cpu.draw(0, 0, 5);
    try expect(V[0xF] == 0);

    // Draw sets VF since a collision happened
    cpu.draw(0, 4, 5);
    try expect(V[0xF] == 1);
}

test "splitMask helper splits masks correctly" {
    var res = Cpu.splitMask(0b10101111, 4);
    try expect(res.left == 0b1010);
    try expect(res.right == 0b11110000);

    res = Cpu.splitMask(0b01001101, 2);
    try expect(res.left == 0b00010011);
    try expect(res.right == 0b01000000);

    res = Cpu.splitMask(0b11001101, 3);
    try expect(res.left == 0b00011001);
    try expect(res.right == 0b10100000);
}

test "Cpu skips next instruction if key in VX is pressed (EX9E)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    test_keypad.pressKey(7);

    V[0xA] = 7;
    cpu.skipIfPressed(0xA);
    try expect(cpu.PC == 0x204);

    V[0xA] = 8;
    cpu.skipIfPressed(0xA);
    try expect(cpu.PC == 0x206);
}

test "Cpu skips next instruction f key in VX is not pressed (EXA1)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    test_keypad.pressKey(7);

    V[0xA] = 7;
    cpu.skipIfNotPressed(0xA);
    try expect(cpu.PC == 0x202);

    V[0xA] = 8;
    cpu.skipIfNotPressed(0xA);
    try expect(cpu.PC == 0x206);
}

test "Cpu stores the value of the delay timer in VX (FX07)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    cpu.delay_timer.value = 10;
    cpu.storeDelayTimer(0xA);
    try expect(V[0xA] == 10);
    try expect(cpu.PC == 0x202);
}

test "Cpu waits for keypress and stores result in VX (FX0A)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    var frame = async cpu.waitForKeypress(0xA);
    cpu.keypad.pressKey(5);
    cpu.keypad.releaseKey(5);
    nosuspend await frame;
    try expect(V[0xA] == 5);
    try expect(cpu.PC == 0x202);

    frame = async cpu.waitForKeypress(0xC);
    cpu.keypad.pressKey(5);
    cpu.keypad.pressKey(6);
    cpu.keypad.pressKey(7);
    cpu.keypad.releaseKey(6);
    nosuspend await frame;

    try expect(V[0xC] == 6);
    try expect(cpu.PC == 0x204);
}

test "Cpu sets delay timer to value found in VX (FX15)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 10;
    cpu.setDelayTimer(0xA);
    try expect(cpu.delay_timer.value == 10);
    try expect(cpu.PC == 0x202);
}

test "Cpu sets sound timer to value found in VX (FX18)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 10;
    cpu.setSoundTimer(0xA);
    try expect(cpu.sound_timer.value == 10);
    try expect(cpu.PC == 0x202);

    // Setting the sound timer to values below 2 has no effect
    V[0xA] = 1;
    cpu.setSoundTimer(0xA);
    try expect(cpu.sound_timer.value == 0);
    try expect(cpu.PC == 0x204);
}

test "Cpu adds the value from VX into I (FX1E)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 5;
    cpu.I = 10;

    cpu.addToI(0xA);
    try expect(cpu.I == 15);
    try expect(cpu.PC == 0x202);
}

test "Cpu sets I to sprite found in VX (FX29)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 5;
    cpu.setSprite(0xA);
    try expect(cpu.I == 25);
    try expect(cpu.PC == 0x202);
}

test "Cpu stores BCD of value in VX at I (FX33)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    V[0xA] = 123;
    cpu.I = 0x500;

    cpu.setBcd(0xA);

    try expect(cpu.mem[0x500] == 1);
    try expect(cpu.mem[0x501] == 2);
    try expect(cpu.mem[0x502] == 3);
    try expect(cpu.PC == 0x202);
}

test "Cpu dumps register into memory I (FX55)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    var i: usize = 0;
    while (i < 16) : (i += 1) {
        V[i] = @intCast(u8, i);
    }

    cpu.I = 0x500;
    cpu.dumpRegisters(5);

    i = 0;
    while (i < 16) : (i += 1) {
        if (i <= 5) {
            try expect(cpu.mem[0x500 + i] == @intCast(u8, i));
        } else {
            try expect(cpu.mem[0x500 + i] == 0);
        }
    }

    try expect(cpu.I == 0x500 + 5 + 1);
    try expect(cpu.PC == 0x202);
}

test "Cpu restores registers from memory I (FX65)" {
    var cpu = getTestCpu();
    const V = cpu.registers();

    var i: usize = 0;
    while (i < 16) : (i += 1) {
        cpu.mem[0x500 + i] = @intCast(u8, i);
    }

    cpu.I = 0x500;
    cpu.restoreRegisters(5);

    while (i < 16) : (i += 1) {
        if (i <= 5) {
            try expect(V[i] == @intCast(u8, i));
        } else {
            try expect(V[i] == 0);
        }
    }

    try expect(cpu.I == 0x500 + 5 + 1);
    try expect(cpu.PC == 0x202);
}

test "decode extracts bits correctly" {
    const first = 0xAB;
    const second = 0xCD;
    const a: u4 = @truncate(u4, @shrExact(first & 0xF0, 4));
    const b: u4 = @truncate(u4, first);
    const c: u4 = @truncate(u4, @shrExact(second & 0xF0, 4));
    const d: u4 = @truncate(u4, second);

    const nnn: u16 = @shlExact(@as(u16, b), 8) + second;

    try expect(a == 0xA);
    try expect(b == 0xB);
    try expect(c == 0xC);
    try expect(d == 0xD);
    try expect(nnn == 0xBCD);
}
