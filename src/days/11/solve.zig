const std = @import("std");
const parse = @import("../../common/parse.zig");
const array = @import("../../common/array.zig");

const bp = @import("../../boilerplate.zig");

const Pos = std.math.Complex(usize);

fn posEq(a: Pos, b: Pos) bool {
    return a.re == b.re and a.im == b.im;
}

fn initPos(row: usize, col: usize) Pos {
    return Pos{ .re = row, .im = col };
}

fn manhattanDistanc(a: Pos, b: Pos) usize {
    return (@max(a.re, b.re) - @min(a.re, b.re)) + (@max(a.im, b.im) - @min(a.im, b.im));
}

pub fn solve(allocator: std.mem.Allocator, file: std.fs.File) anyerror!bp.AoCResult {
    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1000]u8 = undefined;

    var col_has_galaxy = std.ArrayList(bool).init(allocator);
    defer col_has_galaxy.deinit();
    var row_has_galaxy = std.ArrayList(bool).init(allocator);
    defer row_has_galaxy.deinit();

    var galaxies = std.ArrayList(Pos).init(allocator);
    defer galaxies.deinit();

    var rowIdx: usize = 0;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var has_galaxies = false;

        for (line, 0..) |c, colIdx| {
            if (colIdx >= col_has_galaxy.items.len) {
                try col_has_galaxy.append(false);
            }

            if (c == '#') {
                try galaxies.append(initPos(@intCast(rowIdx), @intCast(colIdx)));
                has_galaxies = true;
                col_has_galaxy.items[colIdx] = true;
            }
        }
        try row_has_galaxy.append(has_galaxies);
        rowIdx += 1;
    }

    var row_offsets = try std.ArrayList(u32).initCapacity(allocator, row_has_galaxy.items.len);
    defer row_offsets.deinit();

    try row_offsets.append(0);

    for (row_has_galaxy.items) |rg| {
        const add: u32 = if (rg) 0 else 1;
        try row_offsets.append(row_offsets.getLast() + add);
    }

    var col_offsets = try std.ArrayList(u32).initCapacity(allocator, col_has_galaxy.items.len);
    defer col_offsets.deinit();

    try col_offsets.append(0);

    for (col_has_galaxy.items) |rg| {
        const add: u32 = if (rg) 0 else 1;
        try col_offsets.append(col_offsets.getLast() + add);
    }

    var dist_sum: usize = 0;
    for (galaxies.items, 0..) |g1, idx| {
        const g1_offd = initPos(g1.re + row_offsets.items[g1.re], g1.im + col_offsets.items[g1.im]);
        for (galaxies.items[idx..]) |g2| {
            const g2_offd = initPos(g2.re + row_offsets.items[g2.re], g2.im + col_offsets.items[g2.im]);
            dist_sum += manhattanDistanc(g1_offd, g2_offd);
        }
    }

    const expansion = 999999;

    var dist_sum_2: usize = 0;
    for (galaxies.items, 0..) |g1, idx| {
        const g1_offd = initPos(g1.re + row_offsets.items[g1.re] * expansion, g1.im + col_offsets.items[g1.im] * expansion);
        for (galaxies.items[idx..]) |g2| {
            const g2_offd = initPos(g2.re + row_offsets.items[g2.re] * expansion, g2.im + col_offsets.items[g2.im] * expansion);
            dist_sum_2 += manhattanDistanc(g1_offd, g2_offd);
        }
    }

    return .{ .part1 = dist_sum, .part2 = dist_sum_2 };
}
