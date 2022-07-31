const std = @import("std");
const Scheduler = @import("./scheduler.zig").Scheduler;

pub const Ppu = struct {
    scheduler: *Scheduler,
    const Self = @This();

    pub fn init(scheduler: *Scheduler) Self {
        return .{ .scheduler = scheduler };
    }

    pub fn loop(self: *Self) void {
        var i: usize = 0;
        while (i < 10) : (i += 1) {
            await async self.scheduler.delay(10);
            std.log.info("Done with ppu", .{});
        }
    }
};
