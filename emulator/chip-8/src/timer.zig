pub const Timer = struct {
    value: u8,

    const Self = @This();
    pub fn init(value: u8) Self {
        return .{ .value = value };
    }

    pub fn tick(self: *Self) void {
        // Saturates at 0
        self.value -|= 1;
    }
};
