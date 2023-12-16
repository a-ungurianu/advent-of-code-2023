const std = @import("std");
const parse = @import("../../common/parse.zig");
const array = @import("../../common/array.zig");

const bp = @import("../../boilerplate.zig");

fn hash(line: []const u8) u16 {
    var h: u16 = 0;

    for (line) |c| {
        h += c;
        h *= 17;
        h = h % 256;
    }

    return h;
}

const OpTag = enum {
    remove,
    set,
};

const Operation = struct {
    label: []const u8,
    op: union(OpTag) { remove: void, set: u8 },
};

const Lens = struct { label: []const u8, focus: u8 };
const Box = std.ArrayList(Lens);

fn parseOp(line: []const u8) !Operation {
    const opPos = std.mem.indexOfAny(u8, line, "-=").?;

    if (line[opPos] == '-') {
        return .{
            .label = line[0..opPos],
            .op = .{ .remove = {} },
        };
    }
    if (line[opPos] == '=') {
        const v = try std.fmt.parseUnsigned(u8, line[(opPos + 1)..], 10);
        return .{
            .label = line[0..opPos],
            .op = .{ .set = v },
        };
    }
    unreachable;
}

fn applySet(box: *Box, label: []const u8, focus: u8) !void {
    for (box.items) |*lens| {
        if (std.mem.eql(u8, label, lens.label)) {
            lens.focus = focus;
            return;
        }
    }
    try box.append(.{ .label = label, .focus = focus });
}

fn applyRemove(box: *Box, label: []const u8) !void {
    var optIdx: ?usize = null;

    for (box.items, 0..) |lens, i| {
        if (std.mem.eql(u8, label, lens.label)) {
            optIdx = i;
            break;
        }
    }

    if (optIdx) |idx| {
        _ = box.orderedRemove(idx);
    }
}

fn applyOp(boxes: []Box, op: Operation) !void {
    const boxIdx = hash(op.label);

    switch (op.op) {
        OpTag.set => |set| try applySet(&(boxes[boxIdx]), op.label, set),
        OpTag.remove => try applyRemove(&(boxes[boxIdx]), op.label),
    }
}

fn printBoxes(boxes: []Box) void {
    for (boxes, 0..) |box, i| {
        if (box.items.len > 0) {
            std.debug.print("Box {}: ", .{i});
            for (box.items) |lens| {
                std.debug.print("[{s} {}] ", .{ lens.label, lens.focus });
            }
            std.debug.print("\n", .{});
        }
    }
}

fn calculateFocusPower(boxes: []Box) u64 {
    var res: u64 = 0;

    for (boxes, 0..) |box, boxIdx| {
        for (box.items, 0..) |lens, lensIdx| {
            res += (boxIdx + 1) * (lensIdx + 1) * lens.focus;
        }
    }
    return res;
}

pub fn solve(allocator: std.mem.Allocator, file: std.fs.File) anyerror!bp.AoCResult {
    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var part1: u64 = 0;

    var boxes: [256]Box = undefined;
    for (&boxes) |*box| {
        box.* = Box.init(allocator);
    }
    defer {
        for (boxes) |box| {
            box.deinit();
        }
    }

    const data = (try in_stream.readUntilDelimiterOrEofAlloc(allocator, '\n', 1000000)).?;
    defer allocator.free(data);

    var parts = std.mem.splitScalar(u8, data, ',');

    while (parts.next()) |line| {
        part1 += hash(line);
        try applyOp(&boxes, try parseOp(line));
        // std.debug.print("After \"{s}\"\n", .{line});
        // printBoxes(&boxes);
        // std.debug.print("\n", .{});
    }

    return .{ .part1 = part1, .part2 = calculateFocusPower(&boxes) };
}
