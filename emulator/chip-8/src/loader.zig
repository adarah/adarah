const std = @import("std");
const builtin = @import("builtin");

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

    pub fn loadFonts(buf: []u8) void {
        std.mem.copy(u8, buf, &Loader.FONTS);
        switch (builtin.mode) {
            .Debug => {
                const COSMAC: [48]u8 = [_]u8{
                    0xF9, 0xF3, 0xE6, 0xCF, 0x9F, 0x00, 0x00, 0x00,
                    0x81, 0x12, 0x07, 0xC8, 0x90, 0x00, 0x00, 0x00,
                    0x81, 0x13, 0xE5, 0x4F, 0x90, 0x00, 0x00, 0x00,
                    0x81, 0x10, 0x24, 0x48, 0x90, 0x00, 0x00, 0x00,
                    0xF9, 0xF3, 0xE4, 0x48, 0x90, 0x00, 0x00, 0x00,
                    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                };
                for (buf[0xF00..]) |*b, i| {
                    b.* = COSMAC[i];
                }
            },
            else => {},
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

fn getTestMemory() [4096]u8 {
    return std.mem.zeroes([4096]u8);
}

test "Loader loads fonts" {
    var mem = getTestMemory();
    Loader.loadFonts(&mem);
    for (mem) |byte, i| {
        if (i < 0x50) {
            try expect(byte != 0);
        } else {
            try expect(byte == 0);
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
        try expect(mem[0x200 + i] == i);
    }
}
