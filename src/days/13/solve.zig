const std = @import("std");
const parse = @import("../../common/parse.zig");
const array = @import("../../common/array.zig");

const bp = @import("../../boilerplate.zig");

fn isPalindrome(line: []u8) bool {
    var rev = std.mem.reverseIterator(line);
    for (line) |l| {
        const r = rev.next().?;
        if (l != r) {
            return false;
        }
    }
    return true;
}

fn getCol(lines: std.ArrayList([]u8), col_idx: usize) ![]u8 {
    const col = try lines.allocator.alloc(u8, lines.items.len);

    for (lines.items, 0..) |line, idx| {
        col[idx] = line[col_idx];
    }
    return col;
}

const Res = struct {
    mirror: u64,
    mirror_cand: u64,
};

fn solveSquare(lines: std.ArrayList([]u8)) !Res {
    const line_len = lines.items[0].len;

    var mirror: ?u64 = null;
    var mirror_cand: ?u64 = null;

    for (1..line_len) |can_i| {
        const to_l = can_i;
        const to_r = line_len - can_i;

        const p_l = @min(to_l, to_r);

        var unmatch_count: u32 = 0;
        for (lines.items) |line| {
            if (!isPalindrome(line[(can_i - p_l)..(can_i + p_l)])) {
                unmatch_count += 1;
                if (unmatch_count > 1) {
                    break;
                }
            }
        }
        if (unmatch_count == 0) {
            mirror = can_i;
        }
        if (unmatch_count == 1) {
            mirror_cand = can_i;
        }
        if (mirror != null and mirror_cand != null) {
            break;
        }
    }

    if (mirror == null or mirror_cand == null) {
        const row_len = lines.items.len;

        for (1..row_len) |can_i| {
            const to_l = can_i;
            const to_r = row_len - can_i;

            const p_l = @min(to_l, to_r);

            var unmatch_count: u32 = 0;
            for (0..line_len) |col_i| {
                const line = try getCol(lines, col_i);
                defer lines.allocator.free(line);
                if (!isPalindrome(line[(can_i - p_l)..(can_i + p_l)])) {
                    unmatch_count += 1;
                    if (unmatch_count > 1) {
                        break;
                    }
                }
            }
            if (unmatch_count == 0) {
                mirror = can_i * 100;
            }
            if (unmatch_count == 1) {
                mirror_cand = can_i * 100;
            }
            if (mirror != null and mirror_cand != null) {
                break;
            }
        }
    }

    return .{
        .mirror = mirror.?,
        .mirror_cand = mirror_cand.?,
    };
}

pub fn solve(allocator: std.mem.Allocator, file: std.fs.File) anyerror!bp.AoCResult {
    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var part1: u64 = 0;
    var part2: u64 = 0;
    var lines = std.ArrayList([]u8).init(allocator);
    defer lines.deinit();
    while (try in_stream.readUntilDelimiterOrEofAlloc(allocator, '\n', 1000)) |line| {
        if (line.len == 0) {
            const res = try solveSquare(lines);
            part1 += res.mirror;
            part2 += res.mirror_cand;
            for (lines.items) |line_to_free| {
                allocator.free(line_to_free);
            }
            try lines.resize(0);
        } else {
            try lines.append(line);
        }
    }

    if (lines.items.len > 0) {
        const res = try solveSquare(lines);
        part1 += res.mirror;
        part2 += res.mirror_cand;
        for (lines.items) |line_to_free| {
            allocator.free(line_to_free);
        }
        try lines.resize(0);
    }

    return .{ .part1 = part1, .part2 = part2 };
}
