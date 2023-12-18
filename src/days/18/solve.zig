const std = @import("std");
const parse = @import("../../common/parse.zig");
const array = @import("../../common/array.zig");

const bp = @import("../../boilerplate.zig");

const Dir = enum { n, s, e, w };

const DIRS = [_]Dir{ .n, .s, .e, .w };

const Pos = std.math.Complex(isize);

fn initPos(row: isize, col: isize) Pos {
    return .{ .re = row, .im = col };
}

fn Set(comptime T: type) type {
    return std.AutoHashMap(T, void);
}

fn move(dir: Dir, pos: Pos) Pos {
    return switch (dir) {
        .e => initPos(pos.re, pos.im + 1),
        .w => initPos(pos.re, pos.im - 1),
        .s => initPos(pos.re + 1, pos.im),
        .n => initPos(pos.re - 1, pos.im),
    };
}

const Color = struct { r: u8, g: u8, b: u8 };

const Map = std.AutoHashMap(Pos, Color);

const Move = struct {
    dir: Dir,
    color: Color,
    steps: u32,
};

fn parseMove(line: []const u8) !Move {
    var parts = std.mem.tokenizeAny(u8, line, " ()#");

    const dir_s = parts.next().?[0];

    const dir: Dir = switch (dir_s) {
        'R' => .e,
        'L' => .w,
        'U' => .n,
        'D' => .s,
        else => unreachable,
    };

    const steps = try std.fmt.parseUnsigned(u32, parts.next().?, 10);

    const color_hex = parts.next().?;

    const r = try std.fmt.parseUnsigned(u8, color_hex[0..2], 16);
    const g = try std.fmt.parseUnsigned(u8, color_hex[2..4], 16);
    const b = try std.fmt.parseUnsigned(u8, color_hex[4..6], 16);

    return .{
        .dir = dir,
        .color = .{ .r = r, .g = g, .b = b },
        .steps = steps,
    };
}

fn complexEq(a: Pos, b: Pos) bool {
    return a.re == b.re and a.im == b.im;
}

fn printMap(map: Map, tl: Pos, br: Pos, poi: ?Pos) void {
    var re = tl.re;
    while (re <= br.re) : (re += 1) {
        var im = tl.im;
        while (im <= br.im) : (im += 1) {
            const pos = initPos(@intCast(re), @intCast(im));
            std.debug.print("{s}", .{if (poi != null and complexEq(poi.?, pos)) "X" else if (map.contains(pos)) "#" else "."});
        }
        std.debug.print("\n", .{});
    }
}

fn findPointInside(map: Map, tl: Pos, br: Pos) Pos {
    const mid_row = @divFloor((tl.re + br.re), 2);

    var im = tl.im;

    while (im <= br.im) : (im += 1) {
        const pos = initPos(mid_row, im);
        const next_pos = initPos(mid_row, im + 1);
        if (map.contains(pos) and !map.contains(next_pos)) {
            return next_pos;
        }
    }
    unreachable;
}

fn countInside(map: Map, tl: Pos, br: Pos) !u64 {
    const start = findPointInside(map, tl, br);

    var inside = Set(Pos).init(map.allocator);
    defer inside.deinit();

    var q = std.fifo.LinearFifo(Pos, .Dynamic).init(map.allocator);
    defer q.deinit();

    try q.writeItem(start);
    try inside.put(start, {});

    while (q.readItem()) |pos| {
        for (DIRS) |dir| {
            const next_pos = move(dir, pos);
            const is_wall = map.contains(next_pos);
            if (!is_wall) {
                if (!inside.contains(next_pos)) {
                    // Not already seen
                    try inside.put(next_pos, {});
                    try q.writeItem(next_pos);
                }
            }
        }
    }

    return map.count() + inside.count();
}

pub fn solve(allocator: std.mem.Allocator, file: std.fs.File) anyerror!bp.AoCResult {
    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var map = Map.init(allocator);
    defer map.deinit();

    var buf: [1000]u8 = undefined;

    var c_pos = initPos(0, 0);

    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const dig = try parseMove(line);

        for (0..dig.steps) |_| {
            try map.put(c_pos, dig.color);
            c_pos = move(dig.dir, c_pos);
        }
    }

    var keys = map.keyIterator();

    const key0 = keys.next().?;

    var min_re: isize = key0.re;
    var max_re: isize = key0.re;
    var min_im: isize = key0.im;
    var max_im: isize = key0.im;

    while (keys.next()) |key| {
        min_re = @min(min_re, key.re);
        max_re = @max(max_re, key.re);
        min_im = @min(min_im, key.im);
        max_im = @max(max_im, key.im);
    }

    const count = try countInside(map, initPos(min_re, min_im), initPos(max_re, max_im));

    return .{ .part1 = count, .part2 = 0 };
}
