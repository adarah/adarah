const std = @import("std");
const builtin = @import("builtin");
const wasm = @import("./wasm.zig");
const util = @import("./util.zig");
const Cpu = @import("./cpu.zig").Cpu;
const Loader = @import("./loader.zig").Loader;
const Keypad = @import("./keypad.zig").Keypad;
const Timer = @import("./timer.zig").Timer;

pub const log_level: std.log.Level = .info;

var mem: [4096]u8 = undefined;
var cpu: Cpu = undefined;
var keypad: Keypad = undefined;
var sound_timer: Timer = undefined;
var delay_timer: Timer = undefined;

var cpu_clock_frequency_hz: c_int = undefined;
var prev_time_ms: c_int = undefined;

export fn init(
    seed: c_uint,
    start_time: c_int,
    clock_frequency_hz: c_int,
    shift_quirk: bool,
    register_quirk: bool,
) void {
    cpu_clock_frequency_hz = clock_frequency_hz;
    prev_time_ms = start_time;
    reset();

    keypad = Keypad.init();
    sound_timer = Timer.init(0);
    delay_timer = Timer.init(0);
    cpu = Cpu.init(.{
        .seed = seed,
        .memory = &mem,
        .keypad = &keypad,
        .sound_timer = &sound_timer,
        .delay_timer = &delay_timer,
        .shift_quirk = shift_quirk,
        .register_quirk = register_quirk,
    });
    std.log.info("Initialized emulator!", .{});
}

export fn reset() void {
    Loader.initMem(&mem);
    std.log.info("inited mem", .{});
}

export fn loadGame(game_data: [*]const u8, game_length: c_int) void {
    var game = game_data[0..@intCast(usize, game_length)];
    Loader.loadGame(&mem, game);
    std.log.info("loaded game", .{});
}

export fn onKeydown(key: c_uint) void {
    if (key >= 16) {
        return;
    }
    keypad.pressKey(@intCast(u4, key));
    std.log.debug("Pressed {}!", .{key});
}

export fn onKeyup(key: c_uint) void {
    if (key >= 16) {
        return;
    }
    keypad.releaseKey(@intCast(u4, key));
    std.log.debug("Released {}!", .{key});
}

var global_frame: @Frame(Cpu.fetchDecodeExecute) = undefined;

export fn onAnimationFrame(now_time_ms: c_int) void {
    const elapsed = now_time_ms - prev_time_ms;
    const num_instructions = @divFloor(elapsed * cpu_clock_frequency_hz, 1000);

    std.log.debug("elapsed: {}", .{elapsed});
    // Due to intentional imprecisions in the timer functions in the browser,
    // sometimes now is smaller than previous. Even if the time elapsed is positive,
    // the next frame might be requested too soon (notice the divFloor)
    if (num_instructions <= 0) {
        return;
    }
    prev_time_ms = now_time_ms;

    var i: usize = 0;
    while (i < num_instructions) : (i += 1) {
        global_frame = async cpu.fetchDecodeExecute();
    }
}

export fn timerTick() void {
    sound_timer.tick();
    delay_timer.tick();
    if (sound_timer.value > 0) {
        wasm.playAudio();
    }
}

export fn getMemPtr() [*]u8 {
    return cpu.mem;
}

export fn setCurrentTime(now_time_ms: c_int) void {
    prev_time_ms = now_time_ms;
}

// Functions used by the debugger
export fn debugStep() void {
    global_frame = async cpu.fetchDecodeExecute();
}

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

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = scope;
    switch (level) {
        .err => wasm.err(format, args),
        .warn => wasm.warn(format, args),
        .info => wasm.info(format, args),
        .debug => wasm.debug(format, args),
    }
}
