const std = @import("std");
const bp = @import("./boilerplate.zig");

const Solution = struct { day: u8, solve: bp.Solver };

const solutions = [_]Solution{
    .{ .day = 1, .solve = @import("./days/01/solve.zig").solve },
    .{ .day = 2, .solve = @import("./days/02/solve.zig").solve },
    .{ .day = 3, .solve = @import("./days/03/solve.zig").solve },
    .{ .day = 4, .solve = @import("./days/04/solve.zig").solve },
    .{ .day = 5, .solve = @import("./days/05/solve.zig").solve },
    .{ .day = 6, .solve = @import("./days/06/solve.zig").solve },
    .{ .day = 7, .solve = @import("./days/07/solve.zig").solve },
    .{ .day = 8, .solve = @import("./days/08/solve.zig").solve },
    .{ .day = 9, .solve = @import("./days/09/solve.zig").solve },
    .{ .day = 10, .solve = @import("./days/10/solve.zig").solve },
    .{ .day = 11, .solve = @import("./days/11/solve.zig").solve },
    .{ .day = 12, .solve = @import("./days/12/solve.zig").solve },
    .{ .day = 13, .solve = @import("./days/13/solve.zig").solve },
    .{ .day = 14, .solve = @import("./days/14/solve.zig").solve },
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

    const file = std.fs.openFileAbsolute(dayDir, .{}) catch |err| {
        std.log.err("Failed to open {s}\n", .{dayDir});
        return err;
    };
    const result = try solution.solve(allocator, file);

    std.log.info("[Day {}] Part 1 result: {}", .{ solution.day, result.part1 });
    std.log.info("[Day {}] Part 2 result: {}", .{ solution.day, result.part2 });
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len == 1) {
        inline for (solutions) |solution| {
            try executeSolution(allocator, solution, null);
        }
    }
    if (args.len == 2 or args.len == 3) {
        const day = try std.fmt.parseUnsigned(u8, args[1], 10);
        inline for (solutions) |solution| {
            if (solution.day == day) {
                try executeSolution(allocator, solution, if (args.len == 3) args[2] else null);
            }
        }
    }
}
