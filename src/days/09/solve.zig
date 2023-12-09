const std = @import("std");
const parse = @import("../../common/parse.zig");
const array = @import("../../common/array.zig");

const bp = @import("../../boilerplate.zig");

fn nextReduction(allocator: std.mem.Allocator, vals: std.ArrayList(i32)) !std.ArrayList(i32) {
    var reduction = try std.ArrayList(i32).initCapacity(allocator, vals.items.len - 1);

    for (vals.items[0 .. vals.items.len - 1], vals.items[1..]) |l, r| {
        reduction.appendAssumeCapacity(r - l);
    }
    return reduction;
}

fn isZero(x: i32) bool {
    return x == 0;
}

fn findExtrapolatedValues(allocator: std.mem.Allocator, vals: std.ArrayList(i32)) !struct { first: i32, last: i32 } {
    var reductions = std.ArrayList(std.ArrayList(i32)).init(allocator);
    try reductions.append(vals);
    defer {
        for (reductions.items[1..]) |red| {
            red.deinit();
        }
        reductions.deinit();
    }
    while (!array.every(i32, reductions.getLast().items, isZero)) {
        try reductions.append(try nextReduction(allocator, reductions.getLast()));
    }

    var first: i32 = 0;
    var last: i32 = 0;

    var rev = array.reverseIterator(std.ArrayList(i32), reductions.items);

    while (rev.next()) |red| {
        const l = red.getLast();
        last = last + l;

        const r = red.items[0];

        first = r - first;
    }

    return .{ .first = first, .last = last };
}

pub fn solve(allocator: std.mem.Allocator, file: std.fs.File) anyerror!bp.AoCResult {
    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1000]u8 = undefined;

    var part1: i32 = 0;
    var part2: i32 = 0;

    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var vals = try parse.numbers(i32, allocator, line, " ");
        defer vals.deinit();

        var values = try findExtrapolatedValues(allocator, vals);
        part1 += values.last;
        part2 += values.first;
    }
    return .{ .part1 = @as(u64, @intCast(part1)), .part2 = @as(u64, @intCast(part2)) };
}
