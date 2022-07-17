const std = @import("std");
const wasm = @import("./wasm.zig");
const fmt = std.fmt;
const StaticBitSet = std.bit_set.StaticBitSet;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

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

    pub fn pressKey(self: *Self, key: u4) void {
        self.keys.set(key);

        // const msg = fmt.allocPrint(allocator, "pressed {d}", .{key}) catch "err";
        // defer allocator.free(msg);
        // wasm.consoleLog(msg.ptr, @intCast(c_uint, msg.len));
    }

    pub fn releaseKey(self: *Self, key: u4) void {
        self.keys.unset(key);

        // const msg = fmt.allocPrint(allocator, "released {d}", .{key}) catch "err";
        // defer allocator.free(msg);
        // wasm.consoleLog(msg.ptr, @intCast(c_uint, msg.len));
    }

    pub fn isPressed(self: *Self, key: u4) bool {
        return self.keys.isSet(key);
    }
};

const expect = std.testing.expect;
test "Keypad listens to key presses" {
    var keypad = Keypad.init();

    keypad.pressKey(1);
    try expect(keypad.keys.isSet(1));

    keypad.pressKey(2);
    try expect(keypad.keys.isSet(2));

    keypad.pressKey(0xA);
    try expect(keypad.keys.isSet(0xA));
}

test "Keypad listens to key releases" {
    var keypad = Keypad.init();

    keypad.keys.toggleAll();

    try expect(keypad.keys.isSet(1));
    try expect(keypad.keys.isSet(2));
    try expect(keypad.keys.isSet(0xA));

    keypad.releaseKey(1);
    keypad.releaseKey(2);
    keypad.releaseKey(0xA);

    try expect(!keypad.keys.isSet(1));
    try expect(!keypad.keys.isSet(2));
    try expect(!keypad.keys.isSet(0xA));
}
