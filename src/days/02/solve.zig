const std = @import("std");

const array = @import("../../common/array.zig");

const bp = @import("../../boilerplate.zig");

const CubeCount = struct { red: u32 = 0, green: u32 = 0, blue: u32 = 0 };

const Game = struct { id: u32, picks: std.ArrayList(CubeCount) };

const CAPACITY = CubeCount{ .red = 12, .green = 13, .blue = 14 };

fn fitsInCapacity(capacity: CubeCount, pick: CubeCount) bool {
    if (capacity.blue < pick.blue) return false;
    if (capacity.green < pick.green) return false;
    if (capacity.red < pick.red) return false;
    return true;
}

fn parseCubeCount(line: []const u8) !CubeCount {
    var cube_count = CubeCount{};

    var cube_picks = std.mem.splitScalar(u8, line, ',');
    while (cube_picks.next()) |cube_pick| {
        // Slice to skip the first space
        var parts = std.mem.splitScalar(u8, cube_pick[1..], ' ');

        const count = try std.fmt.parseUnsigned(u32, parts.next().?, 10);

        const color = parts.next().?;

        if (std.mem.eql(u8, color, "blue")) {
            cube_count.blue = count;
        } else if (std.mem.eql(u8, color, "red")) {
            cube_count.red = count;
        } else if (std.mem.eql(u8, color, "green")) {
            cube_count.green = count;
        } else {
            unreachable;
        }
    }

    return cube_count;
}

fn parseCubeCounts(line: []const u8, allocator: std.mem.Allocator) !std.ArrayList(CubeCount) {
    var cube_picks = std.ArrayList(CubeCount).init(allocator);
    errdefer cube_picks.deinit();

    var pick_it = std.mem.split(u8, line, ";");
    while (pick_it.next()) |pick| {
        const parsed_cube_count = try parseCubeCount(pick);
        try cube_picks.append(parsed_cube_count);
    }

    return cube_picks;
}

fn parseGame(line: []const u8, allocator: std.mem.Allocator) !Game {
    var header_game = std.mem.split(u8, line, ":");
    var header = header_game.next().?;

    var game_id = blk: {
        var it = std.mem.split(u8, header, " ");
        _ = it.next();
        break :blk try std.fmt.parseUnsigned(u32, it.next().?, 10);
    };

    var game = header_game.next().?;
    const picks = try parseCubeCounts(game, allocator);

    return Game{ .id = game_id, .picks = picks };
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
        defer game.picks.deinit();

        if (array.every(CubeCount, game.picks.items, fitsInPart1Capacity)) {
            total += game.id;
        }

        var min_cube = CubeCount{};
        for (game.picks.items) |pick| {
            min_cube.red = @max(min_cube.red, pick.red);
            min_cube.blue = @max(min_cube.blue, pick.blue);
            min_cube.green = @max(min_cube.green, pick.green);
        }
        total2 += min_cube.red * min_cube.blue * min_cube.green;
    }

    return bp.AoCResult{ .part1 = total, .part2 = total2 };
}
