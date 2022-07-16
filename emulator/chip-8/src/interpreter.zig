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

    fn screen(self: *Self) *[256]u8 {
        return self.mem[mem_size - 256 ..];
    }

    fn stackPeek(self: *Self) u16 {
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
        self.PC = self.stackPeek();
        self.SP -= 1;
    }

    pub fn jump(self: *Self, address: u16) void {
        self.PC = address;
    }

    pub fn skipIfEqual(self: *Self, register: u4, value: u8) void {
        if (self.V[register] == value) {
            self.PC += 2;
        }
        self.PC += 2;
    }
};

// Tests

const expect = std.testing.expect;
const expectError = std.testing.expectError;

test "Interpreter inits fonts" {
    var vm = Interpreter.init();
    for (vm.mem) |byte, i| {
        if (i >= 0x50) {
            break;
        }
        try expect(byte != 0);
    }
}

test "Interpreter makes syscall" {
    var vm = Interpreter.init();
    try expectError(error.NotImplemented, vm.syscall(0x300));
}

test "Interpreter clears screens" {
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

test "Interpreter returns from subroutine" {
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

test "Interpreter jumps to address" {
    var vm = Interpreter.init();

    vm.jump(0x300);
    try expect(vm.PC == 0x300);

    vm.jump(0x500);
    try expect(vm.PC == 0x500);
}

test "Interpreter calls subroutine" {
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

test "Interpreter skips next instruction if equal" {
    var vm = Interpreter.init();
    vm.V[0xA] = 0xFF;

    vm.skipIfEqual(0xA, 0xFF);
    try expect(vm.PC == 0x204);

    vm.skipIfEqual(0xA, 0xAB);
    try expect(vm.PC == 0x206);
}
