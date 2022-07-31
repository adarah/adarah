const std = @import("std");
const Scheduler = @import("./scheduler.zig").Scheduler;

pub const Cpu = struct {
    scheduler: *Scheduler,

    const Self = @This();

    pub fn init(scheduler: *Scheduler) Self {
        return .{
            .scheduler = scheduler,
        };
    }

    fn fetchDecode(self: *Self) u16 {
        _ = self;
        return 0;
    }

    fn adc(self: *Self) void {
        await async self.scheduler.delay(6);
        std.log.info("in adc!", .{});
        // Do stuff
    }

    pub fn loop(self: *Self) void {
        var i: usize = 0;
        while (i < 10) : (i += 1) {
            const code = self.fetchDecode();
            switch (code) {
                else => await async self.adc(),
            }
        }
    }
};

// const expect = std.testing.expect;
// const expectError = std.testing.expectError;
// const print = std.debug.print;

// fn getTestCpu() Cpu {
//     return Cpu.init();
// }

// test "ADC - Add with Carry" {}
