const std = @import("std");
const parse = @import("../../common/parse.zig");
const array = @import("../../common/array.zig");

const bp = @import("../../boilerplate.zig");

const FCache = std.AutoArrayHashMap(CacheKey, u64);

fn do_dot(cache: *FCache, pattern: []const u8, springs: []const u32, hCount: u32) !u64 {
    if (hCount > 0) {
        if (springs.len > 0) {
            if (springs[0] == hCount) {
                return try f(cache, pattern[1..], springs[1..], 0);
            }
        }
        return 0;
    } else {
        return try f(cache, pattern[1..], springs, 0);
    }
}

const CacheKey = struct {
    pattern_len: usize,
    spring_len: usize,
    hCount: u32,
};

fn toCacheKey(pattern: []const u8, springs: []const u32, hCount: u32) CacheKey {
    return .{ .pattern_len = pattern.len, .spring_len = springs.len, .hCount = hCount };
}

fn f(cache: *FCache, pattern: []const u8, springs: []const u32, hCount: u32) error{OutOfMemory}!u64 {
    const c_key = toCacheKey(pattern, springs, hCount);
    if (cache.get(c_key)) |cached_res| {
        return cached_res;
    }

    const res: u64 = compute: {
        if (pattern.len == 0) {
            if (hCount > 0) {
                if (springs.len == 1 and springs[0] == hCount) {
                    break :compute 1;
                }
            } else {
                if (springs.len == 0) {
                    break :compute 1;
                }
            }
            break :compute 0;
        }

        switch (pattern[0]) {
            '#' => {
                break :compute try f(cache, pattern[1..], springs, hCount + 1);
            },
            '.' => {
                break :compute try do_dot(cache, pattern, springs, hCount);
            },
            '?' => {
                break :compute try f(cache, pattern[1..], springs, hCount + 1) + try do_dot(cache, pattern, springs, hCount);
            },
            else => unreachable,
        }
    };

    try cache.put(c_key, res);
    return res;
}

fn _u32(comptime i: comptime_int) u32 {
    return @intCast(i);
}

test "f" {
    try std.testing.expectEqual(_u32(1), f("#....######..#####.", &[_]u32{ 1, 6, 5 }, 0));
    try std.testing.expectEqual(_u32(0), f("#....######..#####.", &[_]u32{ 1, 6, 4 }, 0));
    try std.testing.expectEqual(_u32(1), f("#.#.###", &[_]u32{ 1, 1, 3 }, 0));
    try std.testing.expectEqual(_u32(1), f(".#...#....###.", &[_]u32{ 1, 1, 3 }, 0));
    try std.testing.expectEqual(_u32(1), f(".#.###.#.######", &[_]u32{ 1, 3, 1, 6 }, 0));
    try std.testing.expectEqual(_u32(1), f("####.#...#...", &[_]u32{ 4, 1, 1 }, 0));

    try std.testing.expectEqual(_u32(1), f("???.###", &[_]u32{ 1, 1, 3 }, 0));
    try std.testing.expectEqual(_u32(4), f(".??..??...?##.", &[_]u32{ 1, 1, 3 }, 0));
    try std.testing.expectEqual(_u32(1), f("?#?#?#?#?#?#?#?", &[_]u32{ 1, 3, 1, 6 }, 0));
    try std.testing.expectEqual(_u32(1), f("????.#...#...", &[_]u32{ 4, 1, 1 }, 0));
    try std.testing.expectEqual(_u32(4), f("????.######..#####.", &[_]u32{ 1, 6, 5 }, 0));
    try std.testing.expectEqual(_u32(10), f("?###????????", &[_]u32{ 3, 2, 1 }, 0));
}

pub fn solve(allocator: std.mem.Allocator, file: std.fs.File) anyerror!bp.AoCResult {
    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1000]u8 = undefined;

    var counts: u64 = 0;
    var counts5: u64 = 0;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var parts = std.mem.splitScalar(u8, line, ' ');

        const pattern = parts.next().?;
        const springs = try parse.numbers(u32, allocator, parts.next().?, ",");
        defer springs.deinit();

        var cache = FCache.init(allocator);
        defer cache.deinit();
        counts += try f(&cache, pattern, springs.items, 0);

        var pattern5 = try std.ArrayList(u8).initCapacity(allocator, pattern.len * 5 + 5);
        defer pattern5.deinit();

        var springs5 = try std.ArrayList(u32).initCapacity(allocator, springs.items.len * 5);
        defer springs5.deinit();
        for (0..5) |i| {
            pattern5.appendSliceAssumeCapacity(pattern);
            if (i < 4) {
                pattern5.appendAssumeCapacity('?');
            }
            springs5.appendSliceAssumeCapacity(springs.items);
        }

        var cache5 = FCache.init(allocator);
        defer cache5.deinit();
        const count5 = try f(&cache5, pattern5.items, springs5.items, 0);
        counts5 += count5;
    }

    return .{ .part1 = counts, .part2 = counts5 };
}
