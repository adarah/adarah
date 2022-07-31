const std = @import("std");
const Allocator = std.mem.Allocator;

const Delay = struct {
    frame: anyframe,
    clock_cycle: usize,
};

fn cmp(context: void, a: Delay, b: Delay) std.math.Order {
    _ = context;
    return std.math.order(a.clock_cycle, b.clock_cycle);
}

pub const Scheduler = struct {
    queue: std.PriorityQueue(Delay, void, cmp),
    clock: usize,

    const Self = @This();
    pub fn init(allocator: Allocator) Self {
        var queue = std.PriorityQueue(Delay, void, cmp).init(allocator, undefined);
        return Self{
            .queue = queue,
            .clock = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.queue.deinit();
        self.* = undefined;
    }

    pub fn delay(self: *Self, delay_cycles: usize) void {
        const d = Delay{
            .frame = @frame(),
            .clock_cycle = self.clock + delay_cycles,
        };
        suspend self.queue.add(d) catch @panic("failed to push event to queue");
    }

    pub fn loop(self: *Self) void {
        while (self.queue.removeOrNull()) |d| {
            self.clock = d.clock_cycle;
            std.log.info("current time: {d}", .{self.clock});
            resume d.frame;
        }
    }
};
