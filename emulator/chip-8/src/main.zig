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

    //     var msg = fmt.allocPrint(allocator, "Pressed {d}", .{key}) catch "err";
    //     defer allocator.free(msg);
    //     wasm.consoleLog(msg.ptr, msg.len);
}

export fn onKeyup(keycode: c_int) void {
    const key = keycodeToKeypad(keycode) catch return;
    keypad.releaseKey(key);

    // var msg = fmt.allocPrint(allocator, "Released {d}", .{key}) catch "err";
    // defer allocator.free(msg);
    // wasm.consoleLog(msg.ptr, msg.len);
}

export fn timerTick() void {
    sound_timer.tick();
    delay_timer.tick();
}

// var wait_frame: @Frame(Cpu.waitForKeypress) = undefined;
// var wait_frame2: @Frame(Cpu.waitForKeypress) = undefined;
// var i: usize = 0;

// export fn waitForKey() void {
//     var msg = fmt.allocPrint(allocator, "waiting for keypress", .{}) catch "err";
//     defer allocator.free(msg);
//     wasm.consoleLog(msg.ptr, msg.len);

//     if (i == 0) {
//         wait_frame = async cpu.waitForKeypress(0xA);
//     } else {
//         wait_frame2 = async cpu.waitForKeypress(0xA);
//     }
//     i += 1;

//     msg = fmt.allocPrint(allocator, "finished waiting {}!", .{i}) catch "err";
//     defer allocator.free(msg);
//     wasm.consoleLog(msg.ptr, msg.len);
// }

// export fn add(a: i32, b: i32) i32 {
//     const ans = a + b;
//     const msg = fmt.allocPrint(allocator, "{d} + {d} is {d}", .{ a, b, ans }) catch "err";
//     defer allocator.free(msg);
//     wasm.consoleLog(msg.ptr, msg.len);
//     return ans;
// }

// test "basic add functionality" {
//     try testing.expect(add(3, 7) == 10);
// }
