const std = @import("std");
const jsFuncs = @import("./js_functions.zig");
const fmt = std.fmt;
const testing = std.testing;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const Interpreter = @import("./interpreter.zig").Interpreter;

var seed = @intCast(u64, jsFuncs.getRandomSeed());
var interpreter = Interpreter.init(seed);
export fn getKeyboardBuffer() [*]const u8 {
    return interpreter.keyboard();
}

export fn emulate() void {
    while (true) {
        const msg = fmt.allocPrint(allocator, "Keyboard reading is {d}", .{interpreter.keyboard()[0]}) catch "err";
        jsFuncs.consoleLog(msg.ptr, msg.len);
    }
}

export fn add(a: i32, b: i32) i32 {
    const ans = a + b;
    const msg = fmt.allocPrint(allocator, "{d} + {d} is {d}", .{ a, b, ans }) catch "err";
    defer allocator.free(msg);
    jsFuncs.consoleLog(msg.ptr, msg.len);
    return ans;
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}
