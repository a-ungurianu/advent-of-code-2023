const std = @import("std");

const array = @import("../../common/array.zig");

const bp = @import("../../boilerplate.zig");

const Dir = enum { left, right };

const NodeId = [3]u8;

fn parseDirs(allocator: std.mem.Allocator, line: []u8) !std.ArrayList(Dir) {
    var res = std.ArrayList(Dir).init(allocator);
    errdefer res.deinit();

    for (line) |c| {
        try res.append(switch (c) {
            'L' => .left,
            'R' => .right,
            else => unreachable,
        });
    }

    return res;
}

fn parseNodeId(buf: []const u8) NodeId {
    var res = NodeId{ 0, 0, 0 };

    std.mem.copy(u8, &res, buf);
    return res;
}

fn isNotZero(n: usize) bool {
    return n != 0;
}

fn lcm(a: u64, b: u64) u64 {
    return (a * b) / std.math.gcd(a, b);
}

pub fn solve(allocator: std.mem.Allocator, file: std.fs.File) anyerror!bp.AoCResult {
    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1000]u8 = undefined;

    const dirs = try parseDirs(allocator, (try in_stream.readUntilDelimiterOrEof(&buf, '\n')).?);
    defer dirs.deinit();

    _ = try in_stream.readUntilDelimiterOrEof(&buf, '\n');

    var edges = std.AutoHashMap(NodeId, [2]NodeId).init(allocator);
    defer edges.deinit();

    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var parts = std.mem.splitSequence(u8, line, " = ");

        var from = parseNodeId(parts.next().?);

        var tos = std.mem.tokenizeAny(u8, parts.next().?, "(, )");

        const to = [2]NodeId{ parseNodeId(tos.next().?), parseNodeId(tos.next().?) };

        try edges.put(from, to);
    }

    var curNode = NodeId{ 'A', 'A', 'A' };
    var dirIdx: usize = 0;
    var stepCount: usize = 0;

    while (!std.mem.eql(u8, &curNode, "ZZZ")) {
        const to = edges.get(curNode) orelse unreachable;

        const dir = dirs.items[dirIdx];

        switch (dir) {
            .left => {
                curNode = to[0];
            },
            .right => {
                curNode = to[1];
            },
        }

        dirIdx = (dirIdx + 1) % dirs.items.len;
        stepCount += 1;
    }

    var init_cur_nodes = std.ArrayList(NodeId).init(allocator);
    defer init_cur_nodes.deinit();

    var keys = edges.keyIterator();
    while (keys.next()) |key| {
        if (key[2] == 'A') {
            try init_cur_nodes.append(parseNodeId(key));
        }
    }

    var cur_nodes = try init_cur_nodes.clone();
    defer cur_nodes.deinit();
    var ghost_step_counts = try std.ArrayList(usize).initCapacity(allocator, cur_nodes.items.len);
    defer ghost_step_counts.deinit();
    ghost_step_counts.appendNTimesAssumeCapacity(0, cur_nodes.items.len);

    dirIdx = 0;
    var ghost_step_count: u64 = 0;
    while (!array.every(usize, ghost_step_counts.items, isNotZero)) {
        for (cur_nodes.items, 0..) |*cur_node, i| {
            if (cur_node.*[2] == 'Z') {
                ghost_step_counts.items[i] = ghost_step_count;
            }
            const to = edges.get(cur_node.*) orelse unreachable;

            const dir = dirs.items[dirIdx];

            switch (dir) {
                .left => {
                    cur_node.* = to[0];
                },
                .right => {
                    cur_node.* = to[1];
                },
            }
        }
        dirIdx = (dirIdx + 1) % dirs.items.len;
        ghost_step_count += 1;
    }

    var res = ghost_step_counts.items[0];

    for (ghost_step_counts.items[1..]) |gs| {
        res = lcm(res, gs);
    }

    return .{ .part1 = stepCount, .part2 = res };
}
