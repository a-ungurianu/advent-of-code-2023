const std = @import("std");
const parse = @import("../../common/parse.zig");
const array = @import("../../common/array.zig");

const bp = @import("../../boilerplate.zig");

fn sum_range(start: u64, end: u64) u64 {
    var s: u64 = 0;
    for (start..end) |i| {
        s += i;
    }
    return s;
}

fn solvePart1(allocator: std.mem.Allocator, platform: std.ArrayList([]u8)) !u64 {
    const row_width = platform.items[0].len;
    const col_width = platform.items.len;

    var res: u64 = 0;

    var colBase = try std.ArrayList(usize).initCapacity(allocator, row_width);
    defer colBase.deinit();
    colBase.appendNTimesAssumeCapacity(col_width + 1, row_width);
    var col_round_count = try std.ArrayList(usize).initCapacity(allocator, row_width);
    defer col_round_count.deinit();
    col_round_count.appendNTimesAssumeCapacity(0, row_width);

    for (platform.items, 0..) |row, row_idx| {
        for (row, 0..) |cell, col_idx| {
            if (cell == 'O') {
                col_round_count.items[col_idx] += 1;
            }
            if (cell == '#') {
                const stack_sum = sum_range(colBase.items[col_idx] - col_round_count.items[col_idx], colBase.items[col_idx]);
                res += stack_sum;

                col_round_count.items[col_idx] = 0;
                colBase.items[col_idx] = col_width - row_idx;
            }
        }
    }
    for (0..col_round_count.items.len) |col_idx| {
        const stack_sum = sum_range(colBase.items[col_idx] - col_round_count.items[col_idx], colBase.items[col_idx]);
        res += stack_sum;
    }

    return res;
}

pub fn solve(allocator: std.mem.Allocator, file: std.fs.File) anyerror!bp.AoCResult {
    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var platform = std.ArrayList([]u8).init(allocator);
    defer {
        for (platform.items) |row| {
            allocator.free(row);
        }
        platform.deinit();
    }

    while (try in_stream.readUntilDelimiterOrEofAlloc(allocator, '\n', 1000)) |line| {
        try platform.append(line);
    }

    const part1 = try solvePart1(allocator, platform);

    return .{ .part1 = part1, .part2 = 0 };
}
