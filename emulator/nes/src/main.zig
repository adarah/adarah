const std = @import("std");
// const builtin = @import("builtin");
const wasm = @import("./wasm.zig");
const Scheduler = @import("./scheduler.zig").Scheduler;
const Nes = @import("./nes.zig").Nes;

pub const log_level: std.log.Level = .info;

pub fn asyncMain() void {}

pub export fn main() void {
    var buffer: [4096]u8 = undefined;
    var fixed_buff_alloc = std.heap.FixedBufferAllocator.init(&buffer);

    var scheduler = Scheduler.init(fixed_buff_alloc.allocator());
    defer scheduler.deinit();

    std.log.info("right before nes init", .{});
    var nes = Nes.init(&scheduler);
    var main_task = async nes.emulate();
    scheduler.loop();
    std.log.info("right after scheduler loop", .{});
    nosuspend await main_task;
    std.log.info("exit 0", .{});
}

// This is the panic handler. Use util.panic instead
pub fn panic(message: []const u8, trace: ?*std.builtin.StackTrace) noreturn {
    @setCold(true);
    _ = trace;
    wasm.err("{s}", .{message});
    wasm.err("{?s}", .{trace});
    while (true) {
        @breakpoint();
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
