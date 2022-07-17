const std = @import("std");
const wasm = @import("./wasm.zig");
const c = @import("./consts.zig");
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

fn keycodeToKeypad(keycode: c_int) !u4 {
    return switch (keycode) {
        c.KEY_1 => 0x1,
        c.KEY_2 => 0x2,
        c.KEY_3 => 0x3,
        c.KEY_4 => 0xC,
        c.KEY_Q => 0x4,
        c.KEY_W => 0x5,
        c.KEY_E => 0x6,
        c.KEY_R => 0xD,
        c.KEY_A => 0x7,
        c.KEY_S => 0x8,
        c.KEY_D => 0x9,
        c.KEY_F => 0xE,
        c.KEY_Z => 0xA,
        c.KEY_X => 0x0,
        c.KEY_C => 0xB,
        c.KEY_V => 0xF,
        else => error.UnknownKey,
    };
}

export fn onKeydown(keycode: c_int) void {
    const key = keycodeToKeypad(keycode) catch return;
    keypad.pressKey(key);
}

export fn onKeyup(keycode: c_int) void {
    const key = keycodeToKeypad(keycode) catch return;
    keypad.releaseKey(key);
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
