const std = @import("std");
const builtin = @import("builtin");
const Mode = std.builtin.Mode;

pub const Loader = struct {
    // In the original COSMAC VIP, the fonts were stored in the ROM at address 8110.
    // Since we are restricted to the 4096 bytes of the interpreter, and modern emulators
    // don't require the reserved 512 bytes in the beginning of the buffer, we just store
    // the fonts at address 0.
    const FONTS: [0x50]u8 = [_]u8{
        0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
        0x20, 0x60, 0x20, 0x20, 0x70, // 1
        0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
        0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
        0x90, 0x90, 0xF0, 0x10, 0x10, // 4
        0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
        0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
        0xF0, 0x10, 0x20, 0x40, 0x40, // 7
        0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
        0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
        0xF0, 0x90, 0xF0, 0x90, 0x90, // A
        0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
        0xF0, 0x80, 0x80, 0x80, 0xF0, // C
        0xE0, 0x90, 0x90, 0x90, 0xE0, // D
        0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
        0xF0, 0x80, 0xF0, 0x80, 0x80, // F
    };

    const GAME_START_ADDRESS = 0x200;

    pub fn initMem(buf: *[4096]u8) void {
        buf.* = std.mem.zeroes([4096]u8);
        std.mem.copy(u8, buf, &Loader.FONTS);

        // In an interpreter written for a contemporary device, the user’s programme should be loaded at 0x0200
        // in the virtual machine RAM and the interpreter should begin execution from that point. However, the
        // original Chip-8 interpreter began execution from 0x01FC. The interpreter includes two permanent Chip-8
        // instructions at this location that are always executed at the start of every programme. The first of
        // these, 0x00E0, clears the display RAM by setting all the bits to zero. The second, 0x004B, calls a
        // machine language routine within the interpreter that switches the VIP’s display on
        buf[0x1FC..0x200].* = .{ 0x00, 0xE0, 0x00, 0x4B };
        // These are the initial values for PC, SP, and I respectively
        buf[0x50..0x56].* = .{ 0x01, 0xFC, 0x0E, 0xCF, 0x00, 0x00 };

        // These bytes show the text COSMAC on the screen. It's ok to have them here since they will be wiped by the
        // initial 0x00E0 instruction at the start of any program
        if (!builtin.is_test) {
            buf[0xF00..0xF30].* = .{
                0xF9, 0xF3, 0xE6, 0xCF, 0x9F, 0x00, 0x00, 0x00,
                0x81, 0x12, 0x07, 0xC8, 0x90, 0x00, 0x00, 0x00,
                0x81, 0x13, 0xE5, 0x4F, 0x90, 0x00, 0x00, 0x00,
                0x81, 0x10, 0x24, 0x48, 0x90, 0x00, 0x00, 0x00,
                0xF9, 0xF3, 0xE4, 0x48, 0x9F, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            };
        }
    }

    pub fn loadGame(buf: []u8, game: []const u8) void {
        for (game) |byte, i| {
            buf[GAME_START_ADDRESS + i] = byte;
        }
    }
};

// Tests

const expect = std.testing.expect;

fn expectEqual(comptime T: type, expected: T, actual: T) !void {
    try std.testing.expectEqual(expected, actual);
}

fn getTestMemory() [4096]u8 {
    return std.mem.zeroes([4096]u8);
}

test "Loader loads fonts" {
    var mem = getTestMemory();
    Loader.initMem(&mem);
    for (mem) |byte, i| {
        if (i < 0x50) {
            // Fonts
            try expectEqual(u8, Loader.FONTS[i], byte);
        } else if (i == 0x1FD or i == 0x1FF or (0x50 <= i and i < 0x54)) {
            // Hardcoded instructions
            try expect(byte != 0);
        } else {
            try expectEqual(u8, 0, byte);
        }
    }
}

test "Loader loads game" {
    var mem = getTestMemory();

    var game: [256]u8 = undefined;
    for (game) |*b, i| {
        b.* = @truncate(u8, i);
    }
    Loader.loadGame(&mem, &game);

    var i: usize = 0;
    while (i < game.len) : (i += 1) {
        try expectEqual(u8, @intCast(u8, i), mem[0x200 + i]);
    }
}
