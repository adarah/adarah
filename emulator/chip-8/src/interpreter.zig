const std = @import("std");
const fmt = std.fmt;
const rand = std.rand;
const panic = std.debug.panic;

const Interpreter = struct {
    const mem_size = 4096;
    mem: [mem_size]u8,
    stack: [16]u16 = std.mem.zeroes([16]u16),
    PC: u16 = 0x200,
    SP: u8 = 0,

    // Registers
    V: [16]u8 = std.mem.zeroes([16]u8),
    I: u16 = 0,

    rand: rand.Random,

    const Self = @This();

    pub fn init(seed: ?u64) Self {
        // Bytes 0x00 trough 0x1FF are reserved for the interpreter, so we store the fonts here.
        var mem = [0x50]u8{
            0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
            0x20, 0x60, 0x20, 0x20, 0x70, // 1
            0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
            0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
            0x90, 0x90, 0xF0, 0x10, 0x10, // 4
            0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
            0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
            0xF0, 0x10, 0x20, 0x40, 0x40, // 7
            0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
            0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
            0xF0, 0x90, 0xF0, 0x90, 0x90, // A
            0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
            0xF0, 0x80, 0x80, 0x80, 0xF0, // C
            0xE0, 0x90, 0x90, 0x90, 0xE0, // D
            0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
            0xF0, 0x80, 0xF0, 0x80, 0x80, // F
        } ++ std.mem.zeroes([4096 - 0x50]u8);

        var _seed: u64 = undefined;
        if (seed) |sd| {
            _seed = sd;
        } else {
            std.os.getrandom(std.mem.asBytes(&_seed)) catch |err| {
                panic("could not gen random bytes to initialize rng: {}", .{err});
            };
        }
        var prng = rand.DefaultPrng.init(_seed);
        const random = prng.random();

        return Self{ .mem = mem, .rand = random };
    }

    inline fn screen(self: *Self) *[256]u8 {
        return self.mem[mem_size - 256 ..];
    }

    inline fn stackPeek(self: *Self) u16 {
        // SP always points to next available position, so SP-1 contains the top of the stack
        return self.stack[self.SP - 1];
    }

    // Instructions

    pub fn syscall(self: *Self, code: u16) !void {
        _ = self;
        _ = code;
        return error.NotImplemented;
    }

    pub fn callSubroutine(self: *Self, address: u16) void {
        self.stack[self.SP] = self.PC;
        self.SP += 1;
        self.PC = address;
    }

    pub fn clearScreen(self: *Self) void {
        for (self.screen()) |*b| {
            b.* = 0;
        }
        self.PC += 2;
    }

    pub fn returnFromSubroutine(self: *Self) void {
        self.SP -= 1;
        self.PC = self.stack[self.SP];
    }

    pub fn jump(self: *Self, address: u16) void {
        self.PC = address;
    }

    pub fn skipIfEqualLiteral(self: *Self, register: u4, value: u8) void {
        if (self.V[register] == value) {
            self.PC += 2;
        }
        self.PC += 2;
    }

    pub fn skipIfNotEqualLiteral(self: *Self, register: u4, value: u8) void {
        if (self.V[register] != value) {
            self.PC += 2;
        }
        self.PC += 2;
    }

    pub fn skipIfEqual(self: *Self, registerX: u4, registerY: u4) void {
        if (self.V[registerX] == self.V[registerY]) {
            self.PC += 2;
        }
        self.PC += 2;
    }

    pub fn storeLiteral(self: *Self, register: u4, value: u8) void {
        self.V[register] = value;
        self.PC += 2;
    }

    pub fn addLiteral(self: *Self, register: u4, value: u8) void {
        self.V[register] +%= value;
        self.PC += 2;
    }

    pub fn store(self: *Self, registerX: u4, registerY: u4) void {
        self.V[registerX] = self.V[registerY];
        self.PC += 2;
    }

    pub fn bitwiseOr(self: *Self, registerX: u4, registerY: u4) void {
        self.V[registerX] |= self.V[registerY];
        self.PC += 2;
    }

    pub fn bitwiseAnd(self: *Self, registerX: u4, registerY: u4) void {
        self.V[registerX] &= self.V[registerY];
        self.PC += 2;
    }

    pub fn bitwiseXor(self: *Self, registerX: u4, registerY: u4) void {
        self.V[registerX] ^= self.V[registerY];
        self.PC += 2;
    }

    pub fn add(self: *Self, registerX: u4, registerY: u4) void {
        const overflow = @addWithOverflow(u8, self.V[registerX], self.V[registerY], &self.V[registerX]);
        self.V[0xF] = @boolToInt(overflow);
        self.PC += 2;
    }

    pub fn sub(self: *Self, registerX: u4, registerY: u4) void {
        const underflow = @subWithOverflow(u8, self.V[registerX], self.V[registerY], &self.V[registerX]);
        self.V[0xF] = @boolToInt(!underflow);
        self.PC += 2;
    }

    pub fn shiftRight(self: *Self, registerX: u4, registerY: u4) void {
        self.V[registerX] = self.V[registerY] >> 1;
        self.V[0xF] = self.V[registerY] & 1;
        self.PC += 2;
    }

    pub fn subStore(self: *Self, registerX: u4, registerY: u4) void {
        const underflow = @subWithOverflow(u8, self.V[registerY], self.V[registerX], &self.V[registerX]);
        self.V[0xF] = @boolToInt(!underflow);
        self.PC += 2;
    }

    pub fn shiftLeft(self: *Self, registerX: u4, registerY: u4) void {
        const overflow = @shlWithOverflow(u8, self.V[registerY], 1, &self.V[registerX]);
        self.V[0xF] = @boolToInt(overflow);
        self.PC += 2;
    }

    pub fn skipIfNotEqual(self: *Self, registerX: u4, registerY: u4) void {
        if (self.V[registerX] != self.V[registerY]) {
            self.PC += 2;
        }
        self.PC += 2;
    }

    pub fn storeAddress(self: *Self, address: u16) void {
        self.I = address;
        self.PC += 2;
    }

    pub fn jumpWithOffset(self: *Self, address: u16) void {
        self.PC = self.V[0] + address;
    }

    pub fn genRandom(self: *Self, register: u4, mask: u8) void {
        self.V[register] = self.rand.int(u8) & mask;
        self.PC += 2;
    }

    // Pixel addresses might not perfectly align with our bytes (happens on 87.5% of cases)
    // When painting pixels, we should fetch the current and the "next" byte.
    // The "next" byte might not be the immediatelly following byte in case we are near one of the edges of the screen.
    // In such situations, we need to wrap around.
    // Once we obtain both bytes, we split the mask in 2 parts and apply it to both of them.
    // Pseudocode:
    // Given the top-left "screen address" of a "pixel row", find the 2 bytes that will be affected
    // Split the mask in two parts, and apply them to both bytes via XOR
    // If any bit is ever unset, we set the VF register.
    pub fn draw(self: *Self, X: u6, Y: u5, height: u5) void {
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
        const _screen = self.screen();
        var i: usize = 0;
        while (i < height) : (i += 1) {
            const offset = 8 * i;
            const sprite_data = self.mem[self.I + i];
            const masks = Interpreter.splitMask(sprite_data, bits_first);
            _screen[@mod(y + x_first + offset, 256)] ^= masks.left;
            _screen[@mod(y + x_second + offset, 256)] ^= masks.right;
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
};

// Tests

const expect = std.testing.expect;
const expectError = std.testing.expectError;
const print = std.debug.print;

test "Interpreter inits fonts" {
    var vm = Interpreter.init(null);
    for (vm.mem) |byte, i| {
        if (i >= 0x50) {
            break;
        }
        try expect(byte != 0);
    }
}

test "Interpreter makes syscall (0NNN)" {
    var vm = Interpreter.init(null);
    try expectError(error.NotImplemented, vm.syscall(0x300));
}

test "Interpreter clears screens (00E0)" {
    var vm = Interpreter.init(null);
    for (vm.screen()) |*b, i| {
        b.* = @intCast(u8, i);
    }

    vm.clearScreen();
    for (vm.screen()) |b| {
        try expect(b == 0);
    }
    try expect(vm.PC == 0x202);
}

test "Interpreter returns from subroutine (00EE)" {
    var vm = Interpreter.init(null);

    vm.stack[0] = 0x500;
    vm.stack[1] = 0x800;
    vm.SP = 2;

    vm.returnFromSubroutine();
    try expect(vm.SP == 1);
    try expect(vm.PC == 0x800);

    vm.returnFromSubroutine();
    try expect(vm.SP == 0);
    try expect(vm.PC == 0x500);
}

test "Interpreter jumps to address (1NNN)" {
    var vm = Interpreter.init(null);

    vm.jump(0x300);
    try expect(vm.PC == 0x300);

    vm.jump(0x500);
    try expect(vm.PC == 0x500);
}

test "Interpreter calls subroutine (2NNN)" {
    var vm = Interpreter.init(null);

    vm.callSubroutine(0x300);
    try expect(vm.PC == 0x300);
    try expect(vm.SP == 1);
    try expect(vm.stackPeek() == 0x200);

    vm.callSubroutine(0x500);
    try expect(vm.PC == 0x500);
    try expect(vm.SP == 2);
    try expect(vm.stackPeek() == 0x300);
}

test "Interpreter skips next instruction if VX equals literal (3XNN)" {
    var vm = Interpreter.init(null);
    vm.V[0xA] = 0xFF;

    vm.skipIfEqualLiteral(0xA, 0xFF);
    try expect(vm.PC == 0x204);

    vm.skipIfEqualLiteral(0xA, 0xAB);
    try expect(vm.PC == 0x206);
}

test "Interpreter skips next instruction if VX not equals literal (4XNN)" {
    var vm = Interpreter.init(null);
    vm.V[0xA] = 0xFF;

    vm.skipIfNotEqualLiteral(0xA, 0xBC);
    try expect(vm.PC == 0x204);

    vm.skipIfNotEqualLiteral(0xA, 0xFF);
    try expect(vm.PC == 0x206);
}

test "Interpreter skips next instruction if VX equals VY (5XY0)" {
    var vm = Interpreter.init(null);
    vm.V[0xA] = 0xFF;
    vm.V[0xB] = 0xFF;

    vm.skipIfEqual(0xA, 0xB);
    try expect(vm.PC == 0x204);

    vm.V[0xB] = 0x21;

    vm.skipIfEqual(0xA, 0xB);
    try expect(vm.PC == 0x206);
}

test "Interpreter stores literal into register (6XNN)" {
    var vm = Interpreter.init(null);

    vm.storeLiteral(0xA, 0xFF);
    try expect(vm.V[0xA] == 0xFF);
    try expect(vm.PC == 0x202);

    vm.storeLiteral(0xC, 0xCC);
    try expect(vm.V[0xC] == 0xCC);
    try expect(vm.PC == 0x204);
}

test "Interpreter adds literal into register (7XNN)" {
    var vm = Interpreter.init(null);

    vm.addLiteral(0xA, 0xFA);
    try expect(vm.V[0xA] == 0xFA);
    try expect(vm.PC == 0x202);

    // Overflows
    vm.addLiteral(0xA, 0x06);
    try expect(vm.V[0xA] == 0x00);
    try expect(vm.PC == 0x204);
}

test "Interpreter stores value from VY into VX (8XY0)" {
    var vm = Interpreter.init(null);
    vm.V[0xB] = 0xBB;

    vm.store(0xA, 0xB);
    try expect(vm.V[0xA] == 0xBB);
    try expect(vm.PC == 0x202);
}

test "Interpreter bitwise ORs VX and VY (8XY1)" {
    var vm = Interpreter.init(null);
    vm.V[0xA] = 0b0110;
    vm.V[0xB] = 0b1001;
    vm.bitwiseOr(0xA, 0xB);
    try expect(vm.V[0xA] == 0b1111);
    try expect(vm.PC == 0x202);
}

test "Interpreter bitwise ANDs VX and VY (8XY2)" {
    var vm = Interpreter.init(null);
    vm.V[0xA] = 0b0110;
    vm.V[0xB] = 0b1001;
    vm.bitwiseAnd(0xA, 0xB);
    try expect(vm.V[0xA] == 0b0000);
    try expect(vm.PC == 0x202);
}

test "Interpreter bitwise XORs VX and VY (8XY3)" {
    var vm = Interpreter.init(null);
    vm.V[0xA] = 0b1010;
    vm.V[0xB] = 0b1001;
    vm.bitwiseXor(0xA, 0xB);
    try expect(vm.V[0xA] == 0b0011);
    try expect(vm.PC == 0x202);
}

test "Interpreter adds registers VX and VY and sets VF if overflow (8XY4)" {
    var vm = Interpreter.init(null);
    vm.V[0xA] = 0xF0;
    vm.V[0xB] = 0x0A;

    vm.add(0xA, 0xB);
    try expect(vm.V[0xA] == 0xFA);
    try expect(vm.V[0xF] == 0);
    try expect(vm.PC == 0x202);

    vm.add(0xA, 0xB);
    try expect(vm.V[0xA] == 0x04);
    try expect(vm.V[0xF] == 1);
    try expect(vm.PC == 0x204);

    vm.add(0xA, 0xB);
    try expect(vm.V[0xA] == 0xE);
    try expect(vm.V[0xF] == 0);
    try expect(vm.PC == 0x206);
}

test "Interpreter subs registers VX and VY and sets VF if no underflow (8XY5)" {
    var vm = Interpreter.init(null);
    vm.V[0xA] = 0x0F;
    vm.V[0xB] = 0x09;

    vm.sub(0xA, 0xB);
    try expect(vm.V[0xA] == 0x06);
    try expect(vm.V[0xF] == 1);
    try expect(vm.PC == 0x202);

    vm.sub(0xA, 0xB);
    try expect(vm.V[0xA] == 0xFD);
    try expect(vm.V[0xF] == 0);
    try expect(vm.PC == 0x204);

    vm.sub(0xA, 0xB);
    try expect(vm.V[0xA] == 0xF4);
    try expect(vm.V[0xF] == 1);
    try expect(vm.PC == 0x206);
}

test "Interpreter right shifts VY into VX and sets VF to the LSB (8XY6)" {
    var vm = Interpreter.init(null);
    vm.V[0xA] = 0;
    vm.V[0xB] = 0b1101;

    vm.shiftRight(0xA, 0xB);
    try expect(vm.V[0xA] == 0b0110);
    try expect(vm.V[0xB] == 0b1101);
    try expect(vm.V[0xF] == 1);
    try expect(vm.PC == 0x202);

    vm.V[0xB] = 0b0010;
    vm.shiftRight(0xA, 0xB);
    try expect(vm.V[0xA] == 0b0001);
    try expect(vm.V[0xB] == 0b0010);
    try expect(vm.V[0xF] == 0);
    try expect(vm.PC == 0x204);
}

test "Interpreter sets VX to 'VY - VX' and sets VF if no underflow (8XY7)" {
    var vm = Interpreter.init(null);
    vm.V[0xA] = 0x09;
    vm.V[0xB] = 0x0A;

    vm.subStore(0xA, 0xB);
    try expect(vm.V[0xA] == 0x01);
    try expect(vm.V[0xF] == 1);
    try expect(vm.PC == 0x202);

    vm.V[0xA] = 0xC;
    vm.subStore(0xA, 0xB);
    try expect(vm.V[0xA] == 0xFE);
    try expect(vm.V[0xF] == 0);
    try expect(vm.PC == 0x204);

    vm.V[0xA] = 0x3;
    vm.subStore(0xA, 0xB);
    try expect(vm.V[0xA] == 0x07);
    try expect(vm.V[0xF] == 1);
    try expect(vm.PC == 0x206);
}

test "Interpreter left shifts VY into VX and sets VF to the MSB (8XYE)" {
    var vm = Interpreter.init(null);
    vm.V[0xA] = 0;
    vm.V[0xB] = 0b11011111;

    vm.shiftLeft(0xA, 0xB);
    try expect(vm.V[0xA] == 0b10111110);
    try expect(vm.V[0xB] == 0b11011111);
    try expect(vm.V[0xF] == 1);
    try expect(vm.PC == 0x202);

    vm.V[0xB] = 0b00101111;
    vm.shiftLeft(0xA, 0xB);
    try expect(vm.V[0xA] == 0b01011110);
    try expect(vm.V[0xB] == 0b00101111);
    try expect(vm.V[0xF] == 0);
    try expect(vm.PC == 0x204);
}

test "Interpreter skips if not equal register (9XY0)" {
    var vm = Interpreter.init(null);
    vm.V[0xA] = 0x5;
    vm.V[0xB] = 0xA;

    vm.skipIfNotEqual(0xA, 0xB);
    try expect(vm.PC == 0x204);

    vm.V[0xB] = 0x5;
    vm.skipIfNotEqual(0xA, 0xB);
    try expect(vm.PC == 0x206);
}

test "Interpreter stores memory address into I (ANNN)" {
    var vm = Interpreter.init(null);

    vm.storeAddress(0x300);
    try expect(vm.I == 0x300);
    try expect(vm.PC == 0x202);
}

test "Interpreter jumps to NNN plus V0 (BNNN)" {
    var vm = Interpreter.init(null);
    vm.V[0] = 0x10;

    vm.jumpWithOffset(0x400);
    try expect(vm.PC == 0x410);
}

test "Interpreter sets VX to a random number with mask (CXNN)" {
    // Wtih seed 0, the first number is 223 = 0b11011111
    var vm = Interpreter.init(0);

    vm.genRandom(0xA, 0b11110000);
    try expect(vm.V[0xA] == 0b11010000);
    try expect(vm.PC == 0x202);
}

test "Interpreter draws sprite (DXYN)" {
    var vm = Interpreter.init(null);
    const s = vm.screen();

    // Draw a 0 at (0, 0).
    // No offset, simplest case.
    vm.I = 0;
    vm.draw(0, 0, 5);

    // Draw a 1 at (16, 0).
    // Has X offset at multiple of 8.
    vm.I = 5;
    vm.draw(16, 0, 5);

    // Draw a 2 at (0, 16).
    // Has Y offset at multiple of 8.
    vm.I = 10;
    vm.draw(0, 16, 5);

    // Draw a 3 at (16, 16).
    // Has X and Y offset at multiples of 8.
    vm.I = 15;
    vm.draw(16, 16, 5);

    // Draw a 5 at (26, 0).
    // Has X and Y offsets, but X is not a multiple of 8
    vm.I = 25;
    vm.draw(25, 0, 5);

    // Draw a 9 at (31, 16).
    // Has X and Y offsets, neither of which are multiples of X
    // The drawing spans 2 separate bytes
    vm.I = 45;
    vm.draw(30, 16, 5);

    // Draw a 7 at (63, 8).
    // This drawing wraps around the X axis.
    vm.I = 35;
    vm.draw(62, 8, 5);

    // Draw a 8 at (8, 30).
    // This drawing wraps around the Y axis.
    vm.I = 40;
    vm.draw(8, 30, 5);

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

test "splitMask helper splits masks correctly" {
    var res = Interpreter.splitMask(0b10101111, 4);
    try expect(res.left == 0b1010);
    try expect(res.right == 0b11110000);

    res = Interpreter.splitMask(0b01001101, 2);
    try expect(res.left == 0b00010011);
    try expect(res.right == 0b01000000);

    res = Interpreter.splitMask(0b11001101, 3);
    try expect(res.left == 0b00011001);
    try expect(res.right == 0b10100000);
}
