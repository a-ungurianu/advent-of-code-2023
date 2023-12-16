const std = @import("std");
const parse = @import("../../common/parse.zig");
const array = @import("../../common/array.zig");

const bp = @import("../../boilerplate.zig");

const Platform = std.ArrayList([]u8);

fn printPlatform(platform: Platform) void {
    for (platform.items) |row| {
        std.debug.print("{s}\n", .{row});
    }
    std.debug.print("\n", .{});
}

const Dir = enum { n, s, e, w };

const Pos = std.math.Complex(isize);

fn initPos(row: isize, col: isize) Pos {
    return .{ .re = row, .im = col };
}

fn inBounds(platform: Platform, pos: Pos) bool {
    const rowCount = platform.items.len;
    const colCount = platform.items[0].len;

    if (0 <= pos.re and pos.re < rowCount and 0 <= pos.im and pos.im < colCount) {
        return true;
    }
    return false;
}

fn Set(comptime T: type) type {
    return std.AutoHashMap(T, void);
}

const Cache = std.AutoHashMap(Beam, Set(Pos));

fn move(dir: Dir, pos: Pos) Pos {
    return switch (dir) {
        .e => initPos(pos.re, pos.im + 1),
        .w => initPos(pos.re, pos.im - 1),
        .s => initPos(pos.re + 1, pos.im),
        .n => initPos(pos.re - 1, pos.im),
    };
}

const Beam = struct { dir: Dir, pos: Pos };

fn count_touched(allocator: std.mem.Allocator, start_beam: Beam, platform: Platform) !Set(Pos) {
    var to_visit = std.fifo.LinearFifo(Beam, .{ .Dynamic = {} }).init(allocator);
    defer to_visit.deinit();

    try to_visit.writeItem(start_beam);

    var visited_beams = Set(Beam).init(allocator);
    defer visited_beams.deinit();
    var visited = Set(Pos).init(allocator);

    while (to_visit.readItem()) |beam| {
        if (!inBounds(platform, beam.pos) or visited_beams.contains(beam)) {
            continue;
        }

        const cell = platform.items[@intCast(beam.pos.re)][@intCast(beam.pos.im)];
        try visited.put(beam.pos, {});
        try visited_beams.put(beam, {});
        if (cell == '.') {
            try to_visit.writeItem(.{ .dir = beam.dir, .pos = move(beam.dir, beam.pos) });
        } else if (cell == '-') {
            if (beam.dir == .e or beam.dir == .w) {
                try to_visit.writeItem(.{ .dir = beam.dir, .pos = move(beam.dir, beam.pos) });
            } else {
                try to_visit.writeItem(.{ .dir = .e, .pos = move(.e, beam.pos) });
                try to_visit.writeItem(.{ .dir = .w, .pos = move(.w, beam.pos) });
            }
        } else if (cell == '|') {
            if (beam.dir == .s or beam.dir == .n) {
                try to_visit.writeItem(.{ .dir = beam.dir, .pos = move(beam.dir, beam.pos) });
            } else {
                try to_visit.writeItem(.{ .dir = .s, .pos = move(.s, beam.pos) });
                try to_visit.writeItem(.{ .dir = .n, .pos = move(.n, beam.pos) });
            }
        } else if (cell == '\\') {
            try to_visit.writeItem(switch (beam.dir) {
                .e => .{ .dir = .s, .pos = move(.s, beam.pos) },
                .w => .{ .dir = .n, .pos = move(.n, beam.pos) },
                .s => .{ .dir = .e, .pos = move(.e, beam.pos) },
                .n => .{ .dir = .w, .pos = move(.w, beam.pos) },
            });
        } else if (cell == '/') {
            try to_visit.writeItem(switch (beam.dir) {
                .e => .{ .dir = .n, .pos = move(.n, beam.pos) },
                .w => .{ .dir = .s, .pos = move(.s, beam.pos) },
                .s => .{ .dir = .w, .pos = move(.w, beam.pos) },
                .n => .{ .dir = .e, .pos = move(.e, beam.pos) },
            });
        } else {
            unreachable;
        }
    }
    return visited;
}

fn print_visited(platform: Platform, visited: Set(Pos)) void {
    for (0..platform.items.len) |rowIdx| {
        for (0..platform.items[0].len) |colIdx| {
            const pos = initPos(@intCast(rowIdx), @intCast(colIdx));

            std.debug.print("{s}", .{[1]u8{if (visited.contains(pos)) '#' else '.'}});
        }
        std.debug.print("\n", .{});
    }
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

    var visited_first = try count_touched(allocator, .{
        .pos = initPos(0, 0),
        .dir = .e,
    }, platform);
    defer visited_first.deinit();

    var max_visited = visited_first.count();

    const row_count = platform.items.len;
    const col_count = platform.items[0].len;

    for (0..row_count) |row_idx| {
        const beam_e = Beam{ .pos = initPos(@intCast(row_idx), 0), .dir = .e };
        const beam_w = Beam{ .pos = initPos(@intCast(row_idx), @intCast(col_count - 1)), .dir = .w };
        var visited = try count_touched(allocator, beam_e, platform);
        max_visited = @max(max_visited, visited.count());
        visited.deinit();

        visited = try count_touched(allocator, beam_w, platform);
        max_visited = @max(max_visited, visited.count());

        visited.deinit();
    }

    for (0..col_count) |col_idx| {
        const beam_s = Beam{ .pos = initPos(0, @intCast(col_idx)), .dir = .s };
        const beam_n = Beam{ .pos = initPos(@intCast(row_count - 1), @intCast(col_idx)), .dir = .n };
        var visited = try count_touched(allocator, beam_s, platform);
        max_visited = @max(max_visited, visited.count());
        visited.deinit();

        visited = try count_touched(allocator, beam_n, platform);
        max_visited = @max(max_visited, visited.count());

        visited.deinit();
    }

    return .{ .part1 = visited_first.count(), .part2 = max_visited };
}
