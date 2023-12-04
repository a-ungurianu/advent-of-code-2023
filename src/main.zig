const std = @import("std");
const bp = @import("./boilerplate.zig");

const Solution = struct { day: u8, solve: bp.Solver };

const solutions = [_]Solution{
    Solution{ .day = 1, .solve = @import("./days/01/solve.zig").solve },
    Solution{ .day = 2, .solve = @import("./days/02/solve.zig").solve },
    Solution{ .day = 3, .solve = @import("./days/03/solve.zig").solve },
};

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

fn executeSolution(allocator: std.mem.Allocator, comptime solution: Solution, input_file: ?[]u8) !void {
    const dayDir = try getDayDir(allocator, solution.day, &[_][]const u8{ "data", input_file orelse "input" });
    defer allocator.free(dayDir);

    var file = std.fs.openFileAbsolute(dayDir, .{}) catch |err| {
        std.log.err("Failed to open {s}\n", .{dayDir});
        return err;
    };
    const result = try solution.solve(file);

    std.log.info("[Day {}] Part 1 result: {}", .{ solution.day, result.part1 });
    std.log.info("[Day {}] Part 2 result: {}", .{ solution.day, result.part2 });
}

pub fn main() anyerror!void {
    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(allocator.deinit() == .ok);

    const args = try std.process.argsAlloc(allocator.allocator());
    defer std.process.argsFree(allocator.allocator(), args);
    if (args.len == 1) {
        inline for (solutions) |solution| {
            try executeSolution(allocator.allocator(), solution, null);
        }
    }
    if (args.len == 2 or args.len == 3) {
        const day = try std.fmt.parseUnsigned(u8, args[1], 10);
        inline for (solutions) |solution| {
            if (solution.day == day) {
                try executeSolution(allocator.allocator(), solution, if (args.len == 3) args[2] else null);
            }
        }
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
