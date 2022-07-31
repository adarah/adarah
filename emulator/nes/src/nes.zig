const Scheduler = @import("./scheduler.zig").Scheduler;
const Cpu = @import("./cpu.zig").Cpu;
const Ppu = @import("./ppu.zig").Ppu;

pub const Nes = struct {
    cpu: Cpu,
    ppu: Ppu,
    const Self = @This();
    pub fn init(scheduler: *Scheduler) Self {
        return .{
            .cpu = Cpu.init(scheduler),
            .ppu = Ppu.init(scheduler),
        };
    }

    pub fn emulate(self: *Self) void {
        var cpu_task = async self.cpu.loop();
        var ppu_task = async self.ppu.loop();
        await cpu_task;
        await ppu_task;
    }
};
