const std = @import("std");
const wasm = @import("./wasm.zig");
const fmt = std.fmt;
const StaticBitSet = std.bit_set.StaticBitSet;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

// ASCII values
const KEY_1 = 49;
const KEY_2 = 50;
const KEY_3 = 51;
const KEY_4 = 52;

const KEY_Q = 113;
const KEY_W = 119;
const KEY_E = 101;
const KEY_R = 114;

const KEY_A = 97;
const KEY_S = 115;
const KEY_D = 100;
const KEY_F = 66;

const KEY_Z = 122;
const KEY_X = 120;
const KEY_C = 99;
const KEY_V = 118;

// A chip-8 keypad is a 16 key square, and each key correspond to a hexadecimal value
// ╔═══╦═══╦═══╦═══╗
// ║ 1 ║ 2 ║ 3 ║ C ║
// ╠═══╬═══╬═══╬═══╣
// ║ 4 ║ 5 ║ 6 ║ D ║
// ╠═══╬═══╬═══╬═══╣
// ║ 7 ║ 8 ║ 9 ║ E ║
// ╠═══╬═══╬═══╬═══╣
// ║ A ║ 0 ║ B ║ F ║
// ╚═══╩═══╩═══╩═══╝

pub const Keypad = struct {
    keys: StaticBitSet(16),

    const Self = @This();

    pub fn init() Self {
        const bitSet = StaticBitSet(16).initEmpty();
        return .{ .keys = bitSet };
    }

    pub fn pressKey(self: *Self, keycode: u32) void {
        const idx = Keypad.keycodeToIndex(keycode) catch return;
        self.keys.set(idx);

        const msg = fmt.allocPrint(allocator, "pressed {d}", .{keycode}) catch "err";
        defer allocator.free(msg);
        wasm.consoleLog(msg.ptr, msg.len);
    }

    pub fn releaseKey(self: *Self, keycode: u32) void {
        const idx = Keypad.keycodeToIndex(keycode) catch return;
        self.keys.unset(idx);

        const msg = fmt.allocPrint(allocator, "released {d}", .{keycode}) catch "err";
        defer allocator.free(msg);
        wasm.consoleLog(msg.ptr, msg.len);
    }

    pub fn isPressed(self: *Self, key: u4) bool {
        return self.keys.isSet(key);
    }

    fn keycodeToIndex(keycode: u32) !u4 {
        return switch (keycode) {
            KEY_1 => 0x1,
            KEY_2 => 0x2,
            KEY_3 => 0x3,
            KEY_4 => 0xC,
            KEY_Q => 0x4,
            KEY_W => 0x5,
            KEY_E => 0x6,
            KEY_R => 0xD,
            KEY_A => 0x7,
            KEY_S => 0x8,
            KEY_D => 0x9,
            KEY_F => 0xE,
            KEY_Z => 0xA,
            KEY_X => 0x0,
            KEY_C => 0xB,
            KEY_V => 0xF,
            else => error.UnknownKey,
        };
    }
};

const expect = std.testing.expect;
test "Keypad listens to key presses" {
    var keypad = Keypad.init();

    keypad.pressKey(KEY_1);
    try expect(keypad.keys.isSet(1));

    keypad.pressKey(KEY_2);
    try expect(keypad.keys.isSet(2));

    keypad.pressKey(KEY_Z);
    try expect(keypad.keys.isSet(0xA));
}

test "Keypad listens to key releases" {
    var keypad = Keypad.init();

    keypad.keys.toggleAll();

    try expect(keypad.keys.isSet(1));
    try expect(keypad.keys.isSet(2));
    try expect(keypad.keys.isSet(0xA));

    keypad.releaseKey(KEY_1);
    keypad.releaseKey(KEY_2);
    keypad.releaseKey(KEY_Z);

    try expect(!keypad.keys.isSet(1));
    try expect(!keypad.keys.isSet(2));
    try expect(!keypad.keys.isSet(0xA));
}
