const std = @import("std");
const builtin = @import("builtin");
const wasm = @import("./wasm.zig");
const util = @import("./util.zig");
const c = @import("./consts.zig");
const Cpu = @import("./cpu.zig").Cpu;
const Loader = @import("./loader.zig").Loader;
const Keypad = @import("./keypad.zig").Keypad;
const Timer = @import("./timer.zig").Timer;
const fmt = std.fmt;
const testing = std.testing;

var cpu: Cpu = undefined;
var keypad: Keypad = undefined;
var sound_timer: Timer = undefined;
var delay_timer: Timer = undefined;

var cpu_clock_frequency_hz: c_int = undefined;
var prev_time_ms: c_int = undefined;

// This is the panic handler. Use util.panic for better convenience.
pub fn panic(message: []const u8, trace: ?*std.builtin.StackTrace) noreturn {
    @setCold(true);
    if (builtin.os.tag == .freestanding) {
        wasm.err("{s}", .{message});
        while (true) {
            @breakpoint();
        }
    } else {
        builtin.default_panic(message, trace);
    }
}

export fn init(seed: c_uint, start_time: c_int, clock_frequency_hz: c_int, shift_quirk: bool, register_quirk: bool, game_data: [*]const u8, game_length: c_int) void {
    cpu_clock_frequency_hz = clock_frequency_hz;
    prev_time_ms = start_time;

    var mem: [4096]u8 = std.mem.zeroes([4096]u8);
    Loader.loadFonts(&mem);

    var game = game_data[0..@intCast(usize, game_length)];
    Loader.loadGame(&mem, game);

    keypad = Keypad.init();
    sound_timer = Timer.init(0);
    delay_timer = Timer.init(0);
    cpu = Cpu.init(.{
        .seed = seed,
        .memory = mem,
        .keypad = &keypad,
        .sound_timer = &sound_timer,
        .delay_timer = &delay_timer,
        .shift_quirk = shift_quirk,
        .register_quirk = register_quirk,
    });
}

export fn onKeydown(keycode: c_int) void {
    const key = util.keycodeToKeypad(keycode) catch return;
    // As noted in the source below, the subroutine to get keyboard input should set the sound timer to 4,
    // which essentially makes the emulator play a sound while the key is being held down
    // https://laurencescotford.com/chip-8-on-the-cosmac-vip-keyboard-input/
    sound_timer.set(4);
    keypad.pressKey(key);
    wasm.log("Pressed {d}", .{key});
}

export fn onKeyup(keycode: c_int) void {
    const key = util.keycodeToKeypad(keycode) catch return;
    keypad.releaseKey(key);
    wasm.log("Released {d}", .{key});
}

var global_frame: @Frame(Cpu.fetchDecodeExecute) = undefined;

export fn onAnimationFrame(now_time_ms: c_int) void {
    const elapsed = now_time_ms - prev_time_ms;
    const num_instructions = @divFloor(elapsed * cpu_clock_frequency_hz, 1000);

    // Due to intentional imprecisions in the timer functions in the browser,
    // sometimes now is smaller than previous. Even if the time elapsed is positive,
    // the next frame might be requested too soon (notice the divFloor)
    if (num_instructions <= 0) {
        return;
    }
    prev_time_ms = now_time_ms;

    // wasm.log("Instructions to execute {d}", .{num_instructions});
    var i: usize = 0;
    while (i < num_instructions) : (i += 1) {
        global_frame = async cpu.fetchDecodeExecute();
    }
    // wasm.log("Executed all", .{});
    const display = cpu.display_buffer();
    wasm.draw(display, display.len);
    // wasm.log("Finished drawing", .{});
}

export fn timerTick() void {
    sound_timer.tick();
    delay_timer.tick();
}

export fn debugStep() void {
    global_frame = async cpu.fetchDecodeExecute();

    const V = cpu.registers();
    wasm.setRegisters(cpu.PC, V, V.len);

    const s = cpu.stack();
    wasm.setStack(cpu.SP, s, s.len);

    const display = cpu.display_buffer();
    wasm.draw(display, display.len);
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
