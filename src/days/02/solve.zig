const std = @import("std");

const bp = @import("../../boilerplate.zig");

const CubeCount = struct { red: u32 = 0, green: u32 = 0, blue: u32 = 0 };

const Game = struct { id: u32, picks: std.ArrayList(CubeCount) };

const CAPACITY = CubeCount{ .red = 12, .green = 13, .blue = 14 };

fn every(comptime T: type, array: std.ArrayList(T), pred: fn (val: T) bool) bool {
    for (array.items) |item| {
        if (!pred(item)) {
            return false;
        }
    }
    return true;
}

fn fitsInCapacity(capacity: CubeCount, pick: CubeCount) bool {
    if (capacity.blue < pick.blue) return false;
    if (capacity.green < pick.green) return false;
    if (capacity.red < pick.red) return false;
    return true;
}

fn parseCubeCount(line: []const u8) !CubeCount {
    var cubeCount = CubeCount{};

    var cubePicks = std.mem.splitScalar(u8, line, ',');
    while (cubePicks.next()) |cubePick| {
        // Slice to skip the first space
        var parts = std.mem.splitScalar(u8, cubePick[1..], ' ');

        const count = try std.fmt.parseUnsigned(u32, parts.next().?, 10);

        const color = parts.next().?;

        if (std.mem.eql(u8, color, "blue")) {
            cubeCount.blue = count;
        } else if (std.mem.eql(u8, color, "red")) {
            cubeCount.red = count;
        } else if (std.mem.eql(u8, color, "green")) {
            cubeCount.green = count;
        } else {
            unreachable;
        }
    }

    return cubeCount;
}

fn parseCubeCounts(line: []const u8, allocator: std.mem.Allocator) !std.ArrayList(CubeCount) {
    var cubePicks = std.ArrayList(CubeCount).init(allocator);
    var pickIt = std.mem.split(u8, line, ";");
    while (pickIt.next()) |pick| {
        const parsedCubeCount = try parseCubeCount(pick);
        try cubePicks.append(parsedCubeCount);
    }

    return cubePicks;
}

fn parseGame(line: []const u8, allocator: std.mem.Allocator) !Game {
    var header_game = std.mem.split(u8, line, ":");
    var header = header_game.next().?;

    var gameId = blk: {
        var it = std.mem.split(u8, header, " ");
        _ = it.next();
        break :blk try std.fmt.parseUnsigned(u32, it.next().?, 10);
    };

    var game = header_game.next().?;
    const picks = try parseCubeCounts(game, allocator);

    return Game{ .id = gameId, .picks = picks };
}

fn fitsInPart1Capacity(pick: CubeCount) bool {
    return fitsInCapacity(CAPACITY, pick);
}

pub fn solve(allocator: std.mem.Allocator, file: std.fs.File) anyerror!bp.AoCResult {
    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [200]u8 = undefined;

    var total: u32 = 0;
    var total2: u32 = 0;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const game = try parseGame(line, allocator);

        if (every(CubeCount, game.picks, fitsInPart1Capacity)) {
            total += game.id;
        }

        var minCube = CubeCount{};
        for (game.picks.items) |pick| {
            minCube.red = @max(minCube.red, pick.red);
            minCube.blue = @max(minCube.blue, pick.blue);
            minCube.green = @max(minCube.green, pick.green);
        }
        total2 += minCube.red * minCube.blue * minCube.green;
        defer game.picks.deinit();
    }

    return bp.AoCResult{ .part1 = total, .part2 = total2 };
}
