const std = @import("std");

extern fn consoleLog(message: [*]const u8, length: usize) void;
extern fn consoleError(message: [*]const u8, length: usize) void;
pub extern fn draw(screen_buffer: [*]const u8, length: usize) void;
pub extern fn setStack(sp: u16, stack_buffer: [*]const u8, length: usize) void;
pub extern fn setRegisters(pc: u16, register_buffer: [*]const u8, length: usize) void;

pub fn log(comptime fmt: []const u8, args: anytype) void {
    var buf: [512]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
    consoleLog(msg.ptr, msg.len);
}

pub fn err(comptime fmt: []const u8, args: anytype) void {
    var buf: [512]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
    consoleError(msg.ptr, msg.len);
}
