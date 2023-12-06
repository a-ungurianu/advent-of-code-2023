const std = @import("std");

const bp = @import("../../boilerplate.zig");

fn parseLine(allocator: std.mem.Allocator, line: []u8) !std.ArrayList(u32) {
    var line_parts = std.mem.splitScalar(u8, line, ':');
    _ = line_parts.next();

    var nums_parts = std.mem.tokenizeScalar(u8, line_parts.next().?, ' ');

    var nums = std.ArrayList(u32).init(allocator);
    errdefer nums.deinit();

    while (nums_parts.next()) |nums_part| {
        try nums.append(try std.fmt.parseUnsigned(u32, nums_part, 10));
    }

    return nums;
}

fn calculateRaceDistance(wait_time: u64, total_time: u64) u64 {
    return (total_time - wait_time) * wait_time;
}

fn countWaysToBeatRace(record_distance: u64, time: u64) u64 {
    var count: u32 = 0;
    _ = count;

    var last_under: u64 = 0;
    // the - 1 at the end is to put us below the half way point of times as
    // f(time) is a quadratic with no offset
    var hop: u64 = @as(u64, @intCast(1)) << (std.math.log2_int(u64, time) - 1);

    while (hop > 0) : (hop >>= 1) {
        const wait_time = last_under + hop;
        if (wait_time <= time) {
            const race_distance = calculateRaceDistance(@as(u64, @intCast(wait_time)), time);
            if (race_distance <= record_distance) {
                last_under = wait_time;
            }
        }
    }

    var last_over: u64 = 0;
    hop = @as(u64, @intCast(1)) << (std.math.log2_int(u64, time));

    while (hop > 0) : (hop >>= 1) {
        const wait_time = last_over + hop;
        if (wait_time <= time) {
            const race_distance = calculateRaceDistance(@as(u64, @intCast(wait_time)), time);
            if (race_distance > record_distance) {
                last_over = wait_time;
            }
        }
    }

    return last_over - (last_under + 1) + 1;
}

pub fn solve(allocator: std.mem.Allocator, file: std.fs.File) anyerror!bp.AoCResult {
    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1000]u8 = undefined;

    const times = try parseLine(allocator, (try in_stream.readUntilDelimiterOrEof(&buf, '\n')).?);
    defer times.deinit();
    const distances = try parseLine(allocator, (try in_stream.readUntilDelimiterOrEof(&buf, '\n')).?);
    defer distances.deinit();

    var part1: u64 = 1;
    for (times.items, distances.items) |time, record_distance| {
        part1 *= countWaysToBeatRace(record_distance, time);
    }

    var big_time: u64 = 0;
    var big_distance: u64 = 0;

    for (times.items, distances.items) |time, distance| {
        const time_digits = std.math.log10(time) + 1;
        big_time = big_time * std.math.pow(u32, 10, time_digits) + time;
        const distance_digits = std.math.log10(distance) + 1;
        big_distance = big_distance * std.math.pow(u32, 10, distance_digits) + distance;
    }

    return .{ .part1 = part1, .part2 = countWaysToBeatRace(big_distance, big_time) };
}
