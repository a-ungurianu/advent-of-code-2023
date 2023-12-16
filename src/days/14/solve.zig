const std = @import("std");
const parse = @import("../../common/parse.zig");
const array = @import("../../common/array.zig");

const bp = @import("../../boilerplate.zig");

fn sum_range(start: u64, end: u64) u64 {
    std.debug.print("[{},{}]\n", .{ start, end });
    var s: u64 = 0;
    for (start..(end)) |i| {
        s += i;
    }
    return s;
}

const Platform = std.ArrayList([]u8);

fn countNorthernWeight(platform: Platform) u64 {
    const row_width = platform.items[0].len;
    const col_width = platform.items.len;
    var res: u64 = 0;

    for (0..col_width) |row_idx| {
        for (0..row_width) |col_idx| {
            const cell = platform.items[row_idx][col_idx];

            if (cell == 'O') {
                res += col_width - row_idx;
            }
        }
    }
    return res;
}

fn shiftNorth(allocator: std.mem.Allocator, platform: Platform) !void {
    const row_width = platform.items[0].len;
    const col_width = platform.items.len;

    var stack_base = try std.ArrayList(usize).initCapacity(allocator, row_width);
    defer stack_base.deinit();
    stack_base.appendNTimesAssumeCapacity(0, row_width);
    var stack_ball_count = try std.ArrayList(usize).initCapacity(allocator, row_width);
    defer stack_ball_count.deinit();
    stack_ball_count.appendNTimesAssumeCapacity(0, row_width);

    for (0..col_width) |row_idx| {
        for (0..row_width) |col_idx| {
            const cell = &(platform.items[row_idx][col_idx]);
            if (cell.* == 'O') {
                stack_ball_count.items[col_idx] += 1;
                cell.* = '.';
            }
            if (cell.* == '#') {
                for ((stack_base.items[col_idx])..(stack_base.items[col_idx] + stack_ball_count.items[col_idx])) |i| {
                    platform.items[i][col_idx] = 'O';
                }

                stack_ball_count.items[col_idx] = 0;
                stack_base.items[col_idx] = row_idx + 1;
            }
        }
    }
    for (0..stack_ball_count.items.len) |col_idx| {
        for ((stack_base.items[col_idx])..(stack_base.items[col_idx] + stack_ball_count.items[col_idx])) |i| {
            platform.items[i][col_idx] = 'O';
        }
    }
}

fn shiftWest(allocator: std.mem.Allocator, platform: Platform) !void {
    const row_width = platform.items[0].len;
    const col_width = platform.items.len;

    var stack_base = try std.ArrayList(usize).initCapacity(allocator, col_width);
    defer stack_base.deinit();
    stack_base.appendNTimesAssumeCapacity(0, col_width);
    var stack_ball_count = try std.ArrayList(usize).initCapacity(allocator, col_width);
    defer stack_ball_count.deinit();
    stack_ball_count.appendNTimesAssumeCapacity(0, col_width);

    for (0..row_width) |col_idx| {
        for (0..col_width) |row_idx| {
            const cell = &(platform.items[row_idx][col_idx]);
            if (cell.* == 'O') {
                stack_ball_count.items[row_idx] += 1;
                cell.* = '.';
            }
            if (cell.* == '#') {
                for ((stack_base.items[row_idx])..(stack_base.items[row_idx] + stack_ball_count.items[row_idx])) |i| {
                    platform.items[row_idx][i] = 'O';
                }

                stack_ball_count.items[row_idx] = 0;
                stack_base.items[row_idx] = col_idx + 1;
            }
        }
    }
    for (0..stack_ball_count.items.len) |row_idx| {
        for ((stack_base.items[row_idx])..(stack_base.items[row_idx] + stack_ball_count.items[row_idx])) |i| {
            platform.items[row_idx][i] = 'O';
        }
    }
}

fn shiftEast(allocator: std.mem.Allocator, platform: Platform) !void {
    const row_width = platform.items[0].len;
    const col_width = platform.items.len;

    var stack_base = try std.ArrayList(usize).initCapacity(allocator, col_width);
    defer stack_base.deinit();
    stack_base.appendNTimesAssumeCapacity(0, col_width);
    var stack_ball_count = try std.ArrayList(usize).initCapacity(allocator, col_width);
    defer stack_ball_count.deinit();
    stack_ball_count.appendNTimesAssumeCapacity(0, col_width);

    for (0..row_width) |col_idx| {
        for (0..col_width) |row_idx| {
            const cell = &(platform.items[row_idx][row_width - col_idx - 1]);
            if (cell.* == 'O') {
                stack_ball_count.items[row_idx] += 1;
                cell.* = '.';
            }
            if (cell.* == '#') {
                for ((stack_base.items[row_idx])..(stack_base.items[row_idx] + stack_ball_count.items[row_idx])) |i| {
                    platform.items[row_idx][row_width - i - 1] = 'O';
                }

                stack_ball_count.items[row_idx] = 0;
                stack_base.items[row_idx] = col_idx + 1;
            }
        }
    }
    for (0..stack_ball_count.items.len) |row_idx| {
        for ((stack_base.items[row_idx])..(stack_base.items[row_idx] + stack_ball_count.items[row_idx])) |i| {
            platform.items[row_idx][row_width - i - 1] = 'O';
        }
    }
}

fn shiftSouth(allocator: std.mem.Allocator, platform: Platform) !void {
    const row_width = platform.items[0].len;
    const col_width = platform.items.len;

    var stack_base = try std.ArrayList(usize).initCapacity(allocator, row_width);
    defer stack_base.deinit();
    stack_base.appendNTimesAssumeCapacity(0, row_width);
    var stack_ball_count = try std.ArrayList(usize).initCapacity(allocator, row_width);
    defer stack_ball_count.deinit();
    stack_ball_count.appendNTimesAssumeCapacity(0, row_width);

    for (0..col_width) |row_idx| {
        for (0..row_width) |col_idx| {
            const cell = &(platform.items[col_width - row_idx - 1][col_idx]);
            if (cell.* == 'O') {
                stack_ball_count.items[col_idx] += 1;
                cell.* = '.';
            }
            if (cell.* == '#') {
                for ((stack_base.items[col_idx])..(stack_base.items[col_idx] + stack_ball_count.items[col_idx])) |i| {
                    platform.items[col_width - i - 1][col_idx] = 'O';
                }

                stack_ball_count.items[col_idx] = 0;
                stack_base.items[col_idx] = row_idx + 1;
            }
        }
    }
    for (0..stack_ball_count.items.len) |col_idx| {
        for ((stack_base.items[col_idx])..(stack_base.items[col_idx] + stack_ball_count.items[col_idx])) |i| {
            platform.items[col_width - i - 1][col_idx] = 'O';
        }
    }
}

fn printPlatform(platform: Platform) void {
    for (platform.items) |row| {
        std.debug.print("{s}\n", .{row});
    }
    std.debug.print("\n", .{});
}

pub fn solve(allocator: std.mem.Allocator, file: std.fs.File) anyerror!bp.AoCResult {
    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var platform = Platform.init(allocator);
    defer {
        for (platform.items) |row| {
            allocator.free(row);
        }
        platform.deinit();
    }

    while (try in_stream.readUntilDelimiterOrEofAlloc(allocator, '\n', 1000)) |line| {
        try platform.append(line);
    }

    try shiftNorth(allocator, platform);

    const part1 = countNorthernWeight(platform);

    var seen = std.AutoHashMap(u64, usize).init(allocator);
    defer seen.deinit();
    var cycle: usize = 0;
    var last: usize = 0;
    for (0..1000) |i| {
        try shiftNorth(allocator, platform);
        try shiftWest(allocator, platform);
        try shiftSouth(allocator, platform);
        try shiftEast(allocator, platform);
        var hasher = std.hash.Wyhash.init(0);
        std.hash.autoHashStrat(&hasher, platform.items, .DeepRecursive);
        const h = hasher.final();

        if (seen.get(h)) |pos| {
            cycle = i - pos;
            last = i;
            break;
        }
        try seen.put(h, i);
    }
    const target: u64 = 1_000_000_000;

    const cycles_to_execute = (target - last) % cycle - 1;

    std.debug.print("cycle_len={} last={} cycles_to_exec={}\n", .{ cycle, last, cycles_to_execute });

    for (0..cycles_to_execute) |i| {
        _ = i;

        try shiftNorth(allocator, platform);
        try shiftWest(allocator, platform);
        try shiftSouth(allocator, platform);
        try shiftEast(allocator, platform);
    }

    return .{ .part1 = part1, .part2 = countNorthernWeight(platform) };
}
