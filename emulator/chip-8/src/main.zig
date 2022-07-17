const std = @import("std");
const wasm = @import("./wasm.zig");
const c = @import("./consts.zig");
const Cpu = @import("./cpu.zig").Cpu;
const Keypad = @import("./keypad.zig").Keypad;
const Timer = @import("./timer.zig").Timer;
const fmt = std.fmt;
const testing = std.testing;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var cpu: Cpu = undefined;
var keypad: Keypad = undefined;
var sound_timer: Timer = undefined;
var delay_timer: Timer = undefined;

export fn init() void {
    const seed = @intCast(u64, wasm.getRandomSeed());
    keypad = Keypad.init();
    sound_timer = Timer.init(0);
    delay_timer = Timer.init(0);
    cpu = Cpu.init(.{
        .seed = seed,
        .keypad = &keypad,
        .sound_timer = &sound_timer,
        .delay_timer = &delay_timer,
    });
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
    // As noted in the source below, the subroutine to get keyboard input should set the sound timer to 4,
    // which essentially makes the emulator play a sound while the key is being held down
    // https://laurencescotford.com/chip-8-on-the-cosmac-vip-keyboard-input/
    sound_timer.set(4);
    keypad.pressKey(key);
}

// The optional arguments for this function will only be set if the `waitForKeypress` instruction was excuted.
// As seen in the reference, the interpreter should only be notified once the key is released.
// https://laurencescotford.com/chip-8-on-the-cosmac-vip-keyboard-input/
export fn onKeyup(keycode: c_int) void {
    const key = keycodeToKeypad(keycode) catch return;
    keypad.releaseKey(key);
}

export fn timer_tick() void {
    sound_timer.tick();
    delay_timer.tick();
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
