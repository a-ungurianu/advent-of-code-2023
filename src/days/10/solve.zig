const std = @import("std");
const parse = @import("../../common/parse.zig");
const array = @import("../../common/array.zig");

const bp = @import("../../boilerplate.zig");

const Pos = std.math.Complex(isize);

fn posEq(a: Pos, b: Pos) bool {
    return a.re == b.re and a.im == b.im;
}

fn initPos(row: isize, col: isize) Pos {
    return Pos{ .re = row, .im = col };
}

// | is a vertical pipe connecting north and south.
// - is a horizontal pipe connecting east and west.
// L is a 90-degree bend connecting north and east.
// J is a 90-degree bend connecting north and west.
// 7 is a 90-degree bend connecting south and west.
// F is a 90-degree bend connecting south and east.

fn charToPipe(c: u8) ?PipeKind {
    return switch (c) {
        '|' => .NS,
        '-' => .EW,
        'L' => .NE,
        'J' => .NW,
        '7' => .SW,
        'F' => .SE,
        else => null,
    };
}

const PipeKind = enum { NS, EW, NE, NW, SW, SE };

const N = initPos(-1, 0);
const S = initPos(1, 0);
const E = initPos(0, 1);
const W = initPos(0, -1);

fn pipeToDirs(pipe: PipeKind) [2]Pos {
    return switch (pipe) {
        .NS => .{ N, S },
        .EW => .{ E, W },
        .NE => .{ N, E },
        .NW => .{ N, W },
        .SW => .{ S, W },
        .SE => .{ S, E },
    };
}

const CellTag = enum { empty, pipe, start };
const Cell = union(CellTag) {
    empty: void,
    start: void,
    pipe: PipeKind,
};

const CellWithTracking = struct {
    cell: Cell,
    distance: ?usize = null,
};

fn parseCell(c: u8) Cell {
    if (c == 'S') {
        return .{ .start = {} };
    }
    if (c == '.') {
        return .{ .empty = {} };
    }

    return .{ .pipe = charToPipe(c) orelse unreachable };
}

const Row = std.ArrayList(CellWithTracking);

fn parseRow(allocator: std.mem.Allocator, line: []u8) !Row {
    var row = try Row.initCapacity(allocator, line.len);
    errdefer row.deinit();

    for (line) |c| {
        row.appendAssumeCapacity(.{ .cell = parseCell(c) });
    }

    return row;
}

const Map = std.ArrayList(Row);

fn debugCell(cell: CellWithTracking) void {
    switch (cell.cell) {
        .empty => std.debug.print("{}", .{CellTag.empty}),
        .start => std.debug.print("{}", .{CellTag.start}),

        .pipe => |pipe| std.debug.print("{}", .{pipe}),
    }
}

fn debugMap(map: Map) void {
    for (map.items) |row| {
        for (row.items) |cell| {
            std.debug.print("{?}\t", .{cell.distance});
        }
        std.debug.print("\n", .{});
    }
    std.debug.print("\n", .{});
}

fn findStartPos(map: Map) Pos {
    for (map.items, 0..) |row, rowIdx| {
        for (row.items, 0..) |cell, colIdx| {
            if (@as(CellTag, cell.cell) == CellTag.start) {
                return initPos(@intCast(rowIdx), @intCast(colIdx));
            }
        }
    }
    unreachable;
}

fn inBounds(map: Map, pos: Pos) bool {
    const rowCount = map.items.len;
    const colCount = map.items[0].items.len;

    if (0 <= pos.re and pos.re < rowCount and 0 <= pos.im and pos.im < colCount) {
        return true;
    }
    return false;
}

fn mapGet(map: Map, pos: Pos) *CellWithTracking {
    return &(map.items[@as(usize, @intCast(pos.re))].items[@as(usize, @intCast(pos.im))]);
}

fn isValidConnection(dir: Pos, cell: Cell) bool {
    switch (cell) {
        .empty => return false,
        .start => return false,
        .pipe => |pipe| {
            if (posEq(dir, N)) {
                return pipe == PipeKind.NS or pipe == PipeKind.SE or pipe == PipeKind.SW;
            }
            if (posEq(dir, S)) {
                return pipe == PipeKind.NS or pipe == PipeKind.NE or pipe == PipeKind.NW;
            }
            if (posEq(dir, E)) {
                return pipe == PipeKind.EW or pipe == PipeKind.NW or pipe == PipeKind.SW;
            }
            if (posEq(dir, W)) {
                return pipe == PipeKind.EW or pipe == PipeKind.SE or pipe == PipeKind.NE;
            }
        },
    }
    unreachable;
}

fn neighboursOf(allocator: std.mem.Allocator, map: Map, pos: Pos) !std.ArrayList(Pos) {
    var neighs = std.ArrayList(Pos).init(allocator);
    errdefer neighs.deinit();

    const cell = mapGet(map, pos).cell;

    switch (cell) {
        .empty => {},
        .start => {
            for ([_]Pos{ N, E, W, S }) |dir| {
                const neigh = dir.add(pos);
                if (inBounds(map, neigh) and isValidConnection(dir, mapGet(map, neigh).cell)) {
                    try neighs.append(neigh);
                }
            }
        },
        .pipe => |pipe| {
            for (pipeToDirs(pipe)) |dir| {
                const neigh = dir.add(pos);
                if (inBounds(map, neigh) and isValidConnection(dir, mapGet(map, neigh).cell)) {
                    try neighs.append(neigh);
                }
            }
        },
    }

    return neighs;
}

fn inferNS(map: Map, n: Pos, s: Pos, _: Pos, _: Pos) bool {
    if (!(inBounds(map, n) and inBounds(map, s))) {
        return false;
    }

    const n_cell = mapGet(map, n);
    const s_cell = mapGet(map, s);

    if (!(n_cell.distance != null and s_cell.distance != null)) {
        return false;
    }

    if (!(@as(CellTag, n_cell.cell) == CellTag.pipe and @as(CellTag, s_cell.cell) == CellTag.pipe)) {
        return false;
    }

    const n_pipe = n_cell.cell.pipe;
    const s_pipe = s_cell.cell.pipe;

    if (!(n_pipe == .NS or n_pipe == .SE or n_pipe == .SW)) {
        return false;
    }

    if (!(s_pipe == .NS or s_pipe == .NE or s_pipe == .NW)) {
        return false;
    }

    return true;
}

fn inferEW(map: Map, _: Pos, _: Pos, e: Pos, w: Pos) bool {
    if (!(inBounds(map, e) and inBounds(map, w))) {
        return false;
    }

    const e_cell = mapGet(map, e);
    const w_cell = mapGet(map, w);

    if (!(e_cell.distance != null and w_cell.distance != null)) {
        return false;
    }

    if (!(@as(CellTag, e_cell.cell) == CellTag.pipe and @as(CellTag, w_cell.cell) == CellTag.pipe)) {
        return false;
    }

    const e_pipe = e_cell.cell.pipe;
    const w_pipe = w_cell.cell.pipe;

    if (!(e_pipe == .EW or e_pipe == .NW or e_pipe == .SW)) {
        return false;
    }

    if (!(w_pipe == .EW or w_pipe == .NE or w_pipe == .SE)) {
        return false;
    }

    return true;
}
fn inferNE(map: Map, n: Pos, _: Pos, e: Pos, _: Pos) bool {
    if (!(inBounds(map, n) and inBounds(map, e))) {
        return false;
    }

    const n_cell = mapGet(map, n);
    const e_cell = mapGet(map, e);

    if (!(n_cell.distance != null and e_cell.distance != null)) {
        return false;
    }

    if (!(@as(CellTag, n_cell.cell) == CellTag.pipe and @as(CellTag, e_cell.cell) == CellTag.pipe)) {
        return false;
    }

    const n_pipe = n_cell.cell.pipe;
    const e_pipe = e_cell.cell.pipe;

    if (!(n_pipe == .NS or n_pipe == .SE or n_pipe == .SW)) {
        return false;
    }

    if (!(e_pipe == .EW or e_pipe == .NW or e_pipe == .SW)) {
        return false;
    }

    return true;
}
fn inferNW(map: Map, n: Pos, s: Pos, e: Pos, w: Pos) bool {
    _ = e;
    _ = s;
    if (!(inBounds(map, n) and inBounds(map, w))) {
        return false;
    }

    const n_cell = mapGet(map, n);
    const w_cell = mapGet(map, w);

    if (!(n_cell.distance != null and w_cell.distance != null)) {
        return false;
    }

    if (!(@as(CellTag, n_cell.cell) == CellTag.pipe and @as(CellTag, w_cell.cell) == CellTag.pipe)) {
        return false;
    }

    const n_pipe = n_cell.cell.pipe;
    const w_pipe = w_cell.cell.pipe;

    if (!(n_pipe == .NS or n_pipe == .SE or n_pipe == .SW)) {
        return false;
    }

    if (!(w_pipe == .EW or w_pipe == .NE or w_pipe == .SE)) {
        return false;
    }

    return true;
}
fn inferSW(map: Map, n: Pos, s: Pos, e: Pos, w: Pos) bool {
    _ = n;
    _ = e;
    if (!(inBounds(map, s) and inBounds(map, w))) {
        return false;
    }

    const s_cell = mapGet(map, s);
    const w_cell = mapGet(map, w);

    if (!(s_cell.distance != null and w_cell.distance != null)) {
        return false;
    }

    if (!(@as(CellTag, s_cell.cell) == CellTag.pipe and @as(CellTag, w_cell.cell) == CellTag.pipe)) {
        return false;
    }

    const s_pipe = s_cell.cell.pipe;
    const w_pipe = w_cell.cell.pipe;

    if (!(s_pipe == .NS or s_pipe == .NE or s_pipe == .NW)) {
        return false;
    }

    if (!(w_pipe == .EW or w_pipe == .NE or w_pipe == .SE)) {
        return false;
    }

    return true;
}
fn inferSE(map: Map, n: Pos, s: Pos, e: Pos, w: Pos) bool {
    _ = w;
    _ = n;
    if (!(inBounds(map, s) and inBounds(map, e))) {
        return false;
    }

    const s_cell = mapGet(map, s);
    const e_cell = mapGet(map, e);

    if (!(s_cell.distance != null and e_cell.distance != null)) {
        return false;
    }

    if (!(@as(CellTag, s_cell.cell) == CellTag.pipe and @as(CellTag, e_cell.cell) == CellTag.pipe)) {
        return false;
    }

    const s_pipe = s_cell.cell.pipe;
    const e_pipe = e_cell.cell.pipe;

    if (!(s_pipe == .NS or s_pipe == .NE or s_pipe == .NW)) {
        return false;
    }

    if (!(e_pipe == .EW or e_pipe == .NW or e_pipe == .SW)) {
        return false;
    }

    return true;
}

const Infer = struct { f: fn (map: Map, n: Pos, s: Pos, e: Pos, w: Pos) bool, p: PipeKind };

const infers = [_]Infer{
    .{ .f = inferNS, .p = .NS },
    .{ .f = inferEW, .p = .EW },
    .{ .f = inferNE, .p = .NE },
    .{ .f = inferNW, .p = .NW },
    .{ .f = inferSE, .p = .SE },
    .{ .f = inferSW, .p = .SW },
};

fn inferCell(map: Map, pos: Pos) PipeKind {
    const n = pos.add(N);
    const s = pos.add(S);
    const e = pos.add(E);
    const w = pos.add(W);

    inline for (infers) |infer| {
        if (infer.f(map, n, s, e, w)) {
            return infer.p;
        }
    }
    unreachable;
}

pub fn solve(allocator: std.mem.Allocator, file: std.fs.File) anyerror!bp.AoCResult {
    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1000]u8 = undefined;

    var map = Map.init(allocator);

    defer {
        for (map.items) |row| {
            row.deinit();
        }
        map.deinit();
    }

    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try map.append(try parseRow(allocator, line));
    }

    const start_pos = findStartPos(map);
    mapGet(map, start_pos).distance = 0;

    var to_visit = std.fifo.LinearFifo(Pos, .{ .Dynamic = {} }).init(allocator);
    defer to_visit.deinit();
    try to_visit.writeItem(start_pos);

    var max_distance: u64 = 0;
    while (to_visit.readItem()) |pos| {
        var curCell = mapGet(map, pos);
        var curDistance = curCell.distance orelse unreachable;

        const neighs = try neighboursOf(allocator, map, pos);
        defer neighs.deinit();

        for (neighs.items) |neigh| {
            var neighCell = mapGet(map, neigh);
            if (neighCell.distance == null and @as(CellTag, neighCell.cell) == CellTag.pipe) {
                neighCell.distance = curDistance + 1;
                max_distance = @max(max_distance, curDistance + 1);
                try to_visit.writeItem(neigh);
            }
        }
    }

    mapGet(map, start_pos).cell = .{ .pipe = inferCell(map, start_pos) };
    var count_inside: u64 = 0;

    for (map.items, 0..) |row, rowIdx| {
        var is_inside = false;
        for (row.items, 0..) |cell_with_dist, colIdx| {
            const cell = cell_with_dist.cell;
            const pos = initPos(@intCast(rowIdx), @intCast(colIdx));
            var s: []const u8 = ".";
            _ = pos;

            if (cell_with_dist.distance) |_| {
                switch (cell) {
                    .pipe => |pipe| {
                        if (pipe == PipeKind.NS or pipe == PipeKind.NE or pipe == PipeKind.NW) {
                            is_inside = !is_inside;
                        }
                    },
                    else => {},
                }
            } else {
                if (is_inside) {
                    s = "#";
                    count_inside += 1;
                }
            }
        }
    }

    return .{ .part1 = max_distance, .part2 = count_inside };
}
