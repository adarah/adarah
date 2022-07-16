const std = @import("std");

const Interpreter = struct {
    const mem_size = 4096;
    mem: [mem_size]u8,
    stack: [16]u16 = std.mem.zeroes([16]u16),
    PC: u16 = 0x200,
    SP: u8 = 0,

    // Registers
    V0: u8 = 0,
    V1: u8 = 0,
    V2: u8 = 0,
    V3: u8 = 0,
    V4: u8 = 0,
    V5: u8 = 0,
    V6: u8 = 0,
    V7: u8 = 0,
    V8: u8 = 0,
    V9: u8 = 0,
    VA: u8 = 0,
    VB: u8 = 0,
    VC: u8 = 0,
    VD: u8 = 0,
    VE: u8 = 0,
    VF: u8 = 0,
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

    pub fn callSubroutine(self: *Self, address: u16) void {
        self.stack[self.SP] = self.PC;
        self.PC = address;
        self.SP += 1;
    }

    pub fn clearScreen(self: *Self) void {
        for (self.screen()) |*b| {
            b.* = 0;
        }
    }

    pub fn returnFromSubroutine(self: *Self) void {
        self.PC = self.stackPeek();
        self.SP -= 1;
    }

    pub fn jump(self: *Self, address: u16) void {
        self.PC = address;
    }
};

const expect = std.testing.expect;
test "Interpreter inits correctly" {
    var vm = Interpreter.init();
    // Fonts are initilizied
    for (vm.mem) |byte, i| {
        if (i >= 0x50) {
            break;
        }
        try expect(byte != 0);
    }
}

test "Interpreter calls subroutine" {
    var vm = Interpreter.init();
    try expect(vm.PC == 0x200);
    try expect(vm.SP == 0);
    vm.callSubroutine(0x300);
    try expect(vm.PC == 0x300);
    try expect(vm.SP == 1);
    try expect(vm.stackPeek() == 0x200);
}

test "Interpreter clears screens" {
    var vm = Interpreter.init();
    var screen = vm.mem[4096 - 256 ..];
    for (screen) |*b, i| {
        b.* = @intCast(u8, i);
    }
    vm.clearScreen();
    for (screen) |b| {
        try expect(b == 0);
    }
}

test "Interpreter returns from subroutine" {
    var vm = Interpreter.init();

    vm.stack[0] = 0x500;
    vm.SP = 1;

    vm.returnFromSubroutine();

    try expect(vm.SP == 0);
    try expect(vm.PC == 0x500);
}

test "Interpreter jumps to address" {
    var vm = Interpreter.init();

    vm.PC = 0x200;
    vm.jump(0x300);
    try expect(vm.PC == 0x300);
}
