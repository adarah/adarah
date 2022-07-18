const std = @import("std");
const c = @import("./consts.zig");
const fmt = std.fmt;

pub fn panic(comptime message: []const u8, args: anytype) noreturn {
    var buf: [512]u8 = undefined;
    const s = fmt.bufPrint(&buf, message, args) catch "internal error writing to panic buffer";
    @panic(s);
}

pub fn keycodeToKeypad(keycode: c_int) !u4 {
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
