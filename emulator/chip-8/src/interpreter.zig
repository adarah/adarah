const std = @import("std");
const fmt = std.fmt;
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

    const Self = @This();

    pub fn init() Self {
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

        return Self{ .mem = mem };
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
};

// Tests

const expect = std.testing.expect;
const expectError = std.testing.expectError;
const print = std.debug.print;

test "Interpreter inits fonts" {
    var vm = Interpreter.init();
    for (vm.mem) |byte, i| {
        if (i >= 0x50) {
            break;
        }
        try expect(byte != 0);
    }
}

test "Interpreter makes syscall (0NNN)" {
    var vm = Interpreter.init();
    try expectError(error.NotImplemented, vm.syscall(0x300));
}

test "Interpreter clears screens (00E0)" {
    var vm = Interpreter.init();
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
    var vm = Interpreter.init();

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
    var vm = Interpreter.init();

    vm.jump(0x300);
    try expect(vm.PC == 0x300);

    vm.jump(0x500);
    try expect(vm.PC == 0x500);
}

test "Interpreter calls subroutine (2NNN)" {
    var vm = Interpreter.init();

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
    var vm = Interpreter.init();
    vm.V[0xA] = 0xFF;

    vm.skipIfEqualLiteral(0xA, 0xFF);
    try expect(vm.PC == 0x204);

    vm.skipIfEqualLiteral(0xA, 0xAB);
    try expect(vm.PC == 0x206);
}

test "Interpreter skips next instruction if VX not equals literal (4XNN)" {
    var vm = Interpreter.init();
    vm.V[0xA] = 0xFF;

    vm.skipIfNotEqualLiteral(0xA, 0xBC);
    try expect(vm.PC == 0x204);

    vm.skipIfNotEqualLiteral(0xA, 0xFF);
    try expect(vm.PC == 0x206);
}

test "Interpreter skips next instruction if VX equals VY (5XY0)" {
    var vm = Interpreter.init();
    vm.V[0xA] = 0xFF;
    vm.V[0xB] = 0xFF;

    vm.skipIfEqual(0xA, 0xB);
    try expect(vm.PC == 0x204);

    vm.V[0xB] = 0x21;

    vm.skipIfEqual(0xA, 0xB);
    try expect(vm.PC == 0x206);
}

test "Interpreter stores literal into register (6XNN)" {
    var vm = Interpreter.init();

    vm.storeLiteral(0xA, 0xFF);
    try expect(vm.V[0xA] == 0xFF);
    try expect(vm.PC == 0x202);

    vm.storeLiteral(0xC, 0xCC);
    try expect(vm.V[0xC] == 0xCC);
    try expect(vm.PC == 0x204);
}

test "Interpreter adds literal into register (7XNN)" {
    var vm = Interpreter.init();

    vm.addLiteral(0xA, 0xFA);
    try expect(vm.V[0xA] == 0xFA);
    try expect(vm.PC == 0x202);

    // Overflows
    vm.addLiteral(0xA, 0x06);
    try expect(vm.V[0xA] == 0x00);
    try expect(vm.PC == 0x204);
}

test "Interpreter stores value from VY into VX (8XY0)" {
    var vm = Interpreter.init();
    vm.V[0xB] = 0xBB;

    vm.store(0xA, 0xB);
    try expect(vm.V[0xA] == 0xBB);
    try expect(vm.PC == 0x202);
}

test "Interpreter bitwise ORs VX and VY (8XY1)" {
    var vm = Interpreter.init();
    vm.V[0xA] = 0b0110;
    vm.V[0xB] = 0b1001;
    vm.bitwiseOr(0xA, 0xB);
    try expect(vm.V[0xA] == 0b1111);
    try expect(vm.PC == 0x202);
}

test "Interpreter bitwise ANDs VX and VY (8XY2)" {
    var vm = Interpreter.init();
    vm.V[0xA] = 0b0110;
    vm.V[0xB] = 0b1001;
    vm.bitwiseAnd(0xA, 0xB);
    try expect(vm.V[0xA] == 0b0000);
    try expect(vm.PC == 0x202);
}

test "Interpreter bitwise XORs VX and VY (8XY3)" {
    var vm = Interpreter.init();
    vm.V[0xA] = 0b1010;
    vm.V[0xB] = 0b1001;
    vm.bitwiseXor(0xA, 0xB);
    try expect(vm.V[0xA] == 0b0011);
    try expect(vm.PC == 0x202);
}

test "Interpreter adds registers VX and VY and sets VF if overflow (8XY4)" {
    var vm = Interpreter.init();
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
    var vm = Interpreter.init();
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
    var vm = Interpreter.init();
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

test "Interpreter sets VX to 'VY - VX' (8XY7) and sets VF if no underflow" {
    var vm = Interpreter.init();
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
