const std = @import("std");
const wasm = @import("./wasm.zig");
const Interpreter = @import("./interpreter.zig").Interpreter;
const Keypad = @import("./keypad.zig").Keypad;
const fmt = std.fmt;
const testing = std.testing;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var interpreter: Interpreter = undefined;
var keypad: Keypad = undefined;

export fn init() void {
    const seed = @intCast(u64, wasm.getRandomSeed());
    interpreter = Interpreter.init(seed);
    keypad = Keypad.init();
}

// JS numbers are f64
export fn onKeydown(keycode: f64) void {
    keypad.pressKey(@floatToInt(u32, keycode));
}

export fn onKeyup(keycode: f64) void {
    keypad.releaseKey(@floatToInt(u32, keycode));
}

// export fn emulate() void {
//     while (true) {
//         const msg = fmt.allocPrint(allocator, "Keyboard reading is {d}", .{interpreter.keyboard()[0]}) catch "err";
//         consoleLog(msg.ptr, msg.len);
//     }
// }

export fn add(a: i32, b: i32) i32 {
    const ans = a + b;
    const msg = fmt.allocPrint(allocator, "{d} + {d} is {d}", .{ a, b, ans }) catch "err";
    defer allocator.free(msg);
    wasm.consoleLog(msg.ptr, msg.len);
    return ans;
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}
