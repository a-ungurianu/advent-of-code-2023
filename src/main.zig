const std = @import("std");
const bp = @import("./boilerplate.zig");

const Solution = struct { day: u8, solve: bp.Solver };

const solutions = [_]Solution{ Solution{ .day = 1, .solve = @import("./days/01/solve.zig").solve }, Solution{ .day = 2, .solve = @import("./days/02/solve.zig").solve } };

fn getDayDir(allocator: std.mem.Allocator, day: u8, path: []const []const u8) ![]u8 {
    const cwd = try std.process.getCwdAlloc(allocator);
    defer allocator.free(cwd);
    var dayBuff: [3]u8 = undefined;
    const dayDir = try std.fmt.bufPrint(&dayBuff, "{:0>2}", .{day});

    var pathBits = std.ArrayList([]const u8).init(allocator);
    defer pathBits.deinit();

    const dayPrefix = [_][]const u8{ cwd, "src", "days", dayDir };
    try pathBits.appendSlice(&dayPrefix);
    try pathBits.appendSlice(path);
    return try std.fs.path.join(allocator, pathBits.items);
}

pub fn main() anyerror!void {
    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(allocator.deinit() == .ok);

    const args = try std.process.argsAlloc(allocator.allocator());
    defer std.process.argsFree(allocator.allocator(), args);
    if (args.len == 1) {
        inline for (solutions) |solution| {
            const dayDir = try getDayDir(allocator.allocator(), solution.day, &[_][]const u8{ "data", "input" });
            defer allocator.allocator().free(dayDir);

            var file = try std.fs.openFileAbsolute(dayDir, .{});
            const result = try solution.solve(file);

            std.log.info("[Day {}] Part 1 result: {}", .{ solution.day, result.part1 });
            std.log.info("[Day {}] Part 2 result: {}", .{ solution.day, result.part2 });
        }
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
