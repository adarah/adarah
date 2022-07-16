const std = @import("std");

const Interpreter = struct {
    mem: [4096]u8,

    const Self = @This();


    pub fn init() Self {
        return Self{
            .mem = std.mem.zeroes([4096]u8),
        };
    }
};

test "Interpreter inits" {
    // const test_allocator = std.testing.allocator;
    const expect = std.testing.expect;

    const vm = Interpreter.init();
    try expect(@TypeOf(vm) == Interpreter);
}