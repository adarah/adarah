const std = @import("std");

pub extern fn consoleDebug(message: [*]const u8, length: usize) void;
pub extern fn consoleInfo(message: [*]const u8, length: usize) void;
pub extern fn consoleWarn(message: [*]const u8, length: usize) void;
pub extern fn consoleError(message: [*]const u8, length: usize) void;

pub extern fn draw(screen_buffer: [*]const u8, length: usize) void;
pub extern fn playAudio() void;
pub extern fn setStack(sp: u16, stack_buffer: [*]const u8, length: usize) void;
pub extern fn setRegisters(pc: u16, register_buffer: [*]const u8, length: usize) void;

pub fn debug(comptime fmt: []const u8, args: anytype) void {
    var buf: [512]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
    consoleDebug(msg.ptr, msg.len);
}

pub fn info(comptime fmt: []const u8, args: anytype) void {
    var buf: [512]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
    consoleInfo(msg.ptr, msg.len);
}

pub fn warn(comptime fmt: []const u8, args: anytype) void {
    var buf: [512]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
    consoleWarn(msg.ptr, msg.len);
}

pub fn err(comptime fmt: []const u8, args: anytype) void {
    var buf: [512]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
    consoleError(msg.ptr, msg.len);
}
