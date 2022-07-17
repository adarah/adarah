const std = @import("std");
const StaticBitSet = std.bit_set.StaticBitSet;

pub const Keypad = struct {
    keys: StaticBitSet(16),

    const Self = @This();

    pub fn init() Self {
        const bitSet = StaticBitSet(16).initEmpty();
        return .{ .keys = bitSet };
    }

    pub fn pressKey(self: *Self, key: u4) void {
        self.keys.set(key);
    }

    pub fn releaseKey(self: *Self, key: u4) void {
        self.keys.unset(key);
    }

    pub fn isPressed(self: *Self, key: u4) bool {
        return self.keys.isSet(key);
    }
};

const expect = std.testing.expect;
test "Keypad listens to key presses" {
    var keypad = Keypad.init();

    keypad.pressKey(0);
    try expect(keypad.keys.isSet(0));

    keypad.pressKey(1);
    try expect(keypad.keys.isSet(1));
}

test "Keypad listens to key releases" {
    var keypad = Keypad.init();

    keypad.keys.toggleAll();

    try expect(keypad.keys.isSet(0));
    try expect(keypad.keys.isSet(1));

    keypad.releaseKey(0);
    keypad.releaseKey(1);

    try expect(!keypad.keys.isSet(0));
    try expect(!keypad.keys.isSet(1));
}
