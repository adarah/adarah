const std = @import("std");
const fmt = std.fmt;

pub fn panic(comptime message: []const u8, args: anytype) noreturn {
    var buf: [512]u8 = undefined;
    const s = fmt.bufPrint(&buf, message, args) catch "internal error writing to panic buffer";
    @panic(s);
}
