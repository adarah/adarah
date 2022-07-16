const std = @import("std");
const fmt = std.fmt;
const testing = std.testing;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

extern fn consoleLog(message: [*]const u8, length: u32) void;

export fn add(a: i32, b: i32) i32 {
    const ans = a + b;
    const msg = fmt.allocPrint(allocator, "{d} + {d} is {d}", .{ a, b, ans }) catch "err";
    defer allocator.free(msg);
    consoleLog(msg.ptr, msg.len);
    return ans;
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}
