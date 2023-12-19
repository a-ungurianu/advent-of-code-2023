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

const DIRS = [_]Dir{ .n, .s, .e, .w };

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

const State = struct {
    pos: Pos,
    dir: Dir,
    steps_in_same_dir: u8,
    cost: u64,
};

const CostKey = struct { pos: Pos, dir: Dir, steps_in_same_dir: u8 };

const Costs = std.AutoArrayHashMap(CostKey, u64);
const NodeInQ = std.AutoArrayHashMap(CostKey, State);

fn oppositeDir(dir: Dir) Dir {
    return switch (dir) {
        .e => .w,
        .w => .e,
        .s => .n,
        .n => .s,
    };
}

fn compareState(context: void, a: State, b: State) std.math.Order {
    _ = context;
    const orders = [_]std.math.Order{
        std.math.order(a.cost, b.cost),
        std.math.order(a.steps_in_same_dir, b.steps_in_same_dir),
        std.math.order(@intFromEnum(a.dir), @intFromEnum(b.dir)),
        std.math.order(a.pos.re, b.pos.re),
        std.math.order(a.pos.im, b.pos.im),
    };

    for (orders) |order| {
        if (order != std.math.Order.eq) {
            return order;
        }
    }
    return std.math.Order.eq;
}

fn stateToCostKey(state: State) CostKey {
    return .{ .pos = state.pos, .dir = state.dir, .steps_in_same_dir = state.steps_in_same_dir };
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

    const part1 = part1: {
        var costs = Costs.init(allocator);
        defer costs.deinit();

        var to_visit = std.PriorityQueue(State, void, compareState).init(allocator, {});
        defer to_visit.deinit();

        const start = State{ .pos = initPos(0, 0), .dir = .e, .steps_in_same_dir = 0, .cost = 0 };

        try to_visit.add(start);

        const end = initPos(@intCast(platform.items.len - 1), @intCast(platform.items[0].len - 1));
        while (to_visit.removeOrNull()) |step| {
            const step_key = stateToCostKey(step);

            const step_cost = costs.get(step_key) orelse 0;
            for (DIRS) |dir| {
                if (dir == oppositeDir(step.dir)) continue;
                const next = move(dir, step.pos);
                if (!inBounds(platform, next)) continue;
                const nextCost = step_cost + (platform.items[@intCast(next.re)][@intCast(next.im)] - '0');
                if (dir == step.dir) {
                    if (step.steps_in_same_dir < 3) {
                        const next_step = State{ .pos = next, .dir = dir, .steps_in_same_dir = step.steps_in_same_dir + 1, .cost = nextCost };
                        const key = stateToCostKey(next_step);
                        if (costs.get(key)) |cost| {
                            if (cost < nextCost) {
                                continue;
                            } else {
                                try to_visit.update(.{
                                    .pos = next_step.pos,
                                    .dir = next_step.dir,
                                    .steps_in_same_dir = next_step.steps_in_same_dir,
                                    .cost = cost,
                                }, next_step);
                            }
                        } else {
                            try to_visit.add(next_step);
                        }
                        try costs.put(key, nextCost);
                    }
                } else {
                    const next_step = State{ .pos = next, .dir = dir, .steps_in_same_dir = 1, .cost = nextCost };
                    const key = stateToCostKey(next_step);
                    if (costs.get(key)) |cost| {
                        if (cost < nextCost) {
                            continue;
                        } else {
                            try to_visit.update(.{
                                .pos = next_step.pos,
                                .dir = next_step.dir,
                                .steps_in_same_dir = next_step.steps_in_same_dir,
                                .cost = cost,
                            }, next_step);
                        }
                    } else {
                        try to_visit.add(next_step);
                    }
                    try costs.put(key, nextCost);
                }
            }
        }

        var minCost: u64 = 1000000000;
        for (DIRS) |dir| {
            for (0..4) |steps_in_same_dir| {
                if (costs.get(.{ .pos = end, .dir = dir, .steps_in_same_dir = @intCast(steps_in_same_dir) })) |cost| {
                    minCost = @min(minCost, cost);
                }
            }
        }
        break :part1 minCost;
    };

    const part2 = part2: {
        var costs = Costs.init(allocator);
        defer costs.deinit();

        var to_visit = std.PriorityQueue(State, void, compareState).init(allocator, {});
        defer to_visit.deinit();

        const start = State{ .pos = initPos(0, 0), .dir = .e, .steps_in_same_dir = 0, .cost = 0 };

        try to_visit.add(start);

        const end = initPos(@intCast(platform.items.len - 1), @intCast(platform.items[0].len - 1));
        while (to_visit.removeOrNull()) |step| {
            const step_key = stateToCostKey(step);

            const step_cost = costs.get(step_key) orelse 0;

            if (step.steps_in_same_dir < 4 and step.steps_in_same_dir != 0) {
                const next = move(step.dir, step.pos);
                var edge = next;
                var steps_taken = step.steps_in_same_dir + 1;
                while (steps_taken < 4) {
                    edge = move(step.dir, edge);
                    steps_taken += 1;
                }

                if (!inBounds(platform, next) or !inBounds(platform, edge)) continue;
                const nextCost = step_cost + (platform.items[@intCast(next.re)][@intCast(next.im)] - '0');
                const next_step = State{ .pos = next, .dir = step.dir, .steps_in_same_dir = step.steps_in_same_dir + 1, .cost = nextCost };
                const key = stateToCostKey(next_step);
                if (costs.get(key)) |cost| {
                    if (cost < nextCost) {
                        continue;
                    } else {
                        try to_visit.update(.{
                            .pos = next_step.pos,
                            .dir = next_step.dir,
                            .steps_in_same_dir = next_step.steps_in_same_dir,
                            .cost = cost,
                        }, next_step);
                    }
                } else {
                    try to_visit.add(next_step);
                }
                try costs.put(key, nextCost);
            } else {
                for (DIRS) |dir| {
                    if (dir == oppositeDir(step.dir)) continue;
                    const next = move(dir, step.pos);
                    if (!inBounds(platform, next)) continue;
                    const nextCost = step_cost + (platform.items[@intCast(next.re)][@intCast(next.im)] - '0');
                    if (dir == step.dir) {
                        if (step.steps_in_same_dir < 10) {
                            const next_step = State{ .pos = next, .dir = dir, .steps_in_same_dir = step.steps_in_same_dir + 1, .cost = nextCost };
                            const key = stateToCostKey(next_step);
                            if (costs.get(key)) |cost| {
                                if (cost < nextCost) {
                                    continue;
                                } else {
                                    try to_visit.update(.{
                                        .pos = next_step.pos,
                                        .dir = next_step.dir,
                                        .steps_in_same_dir = next_step.steps_in_same_dir,
                                        .cost = cost,
                                    }, next_step);
                                }
                            } else {
                                try to_visit.add(next_step);
                            }
                            try costs.put(key, nextCost);
                        }
                    } else {
                        const next_step = State{ .pos = next, .dir = dir, .steps_in_same_dir = 1, .cost = nextCost };
                        const key = stateToCostKey(next_step);
                        if (costs.get(key)) |cost| {
                            if (cost < nextCost) {
                                continue;
                            } else {
                                try to_visit.update(.{
                                    .pos = next_step.pos,
                                    .dir = next_step.dir,
                                    .steps_in_same_dir = next_step.steps_in_same_dir,
                                    .cost = cost,
                                }, next_step);
                            }
                        } else {
                            try to_visit.add(next_step);
                        }
                        try costs.put(key, nextCost);
                    }
                }
            }
        }

        var minCost: u64 = 1000000000;
        for (DIRS) |dir| {
            for (0..4) |steps_in_same_dir| {
                if (costs.get(.{ .pos = end, .dir = dir, .steps_in_same_dir = @intCast(steps_in_same_dir) })) |cost| {
                    minCost = @min(minCost, cost);
                }
            }
        }
        break :part2 minCost;
    };

    return .{ .part1 = part1, .part2 = part2 };
}
