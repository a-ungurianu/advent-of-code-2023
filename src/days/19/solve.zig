const std = @import("std");

const bp = @import("../../boilerplate.zig");

const ConditionTag = enum {
    lt,
    gt,
    e,
};

const Condition = union(ConditionTag) {
    lt: struct { v: u8, l: u32 },
    gt: struct { v: u8, l: u32 },
    e: void,
};

const TargetTag = enum {
    jump,
    accept,
    reject,
};

const Target = union(TargetTag) {
    jump: []u8,
    accept: void,
    reject: void,
};

const Rule = struct {
    condition: Condition,
    target: Target,
};

const Program = struct {
    label: []u8,
    rules: std.ArrayList(Rule),
};

fn parseCondition(line: []const u8) !Condition {
    const v = line[0];
    const o = line[1];
    const l = try std.fmt.parseUnsigned(u32, line[2..], 10);

    return switch (o) {
        '>' => .{ .gt = .{ .v = v, .l = l } },
        '<' => .{ .lt = .{ .v = v, .l = l } },
        else => unreachable,
    };
}

fn parseTarget(allocator: std.mem.Allocator, line: []const u8) !Target {
    if (std.mem.eql(u8, "A", line)) {
        return .{ .accept = {} };
    }
    if (std.mem.eql(u8, "R", line)) {
        return .{ .reject = {} };
    }

    return .{ .jump = try allocator.dupe(u8, line) };
}

fn parseRule(allocator: std.mem.Allocator, line: []const u8) !Rule {
    var parts = std.mem.splitScalar(u8, line, ':');

    const first = parts.next().?;

    if (parts.next()) |second| {
        return .{
            .condition = try parseCondition(first),
            .target = try parseTarget(allocator, second),
        };
    } else {
        return .{
            .condition = .{ .e = {} },
            .target = try parseTarget(allocator, first),
        };
    }
}

fn parseProgram(allocator: std.mem.Allocator, line: []u8) !Program {
    var parts = std.mem.tokenizeAny(u8, line, "{},");

    const label = try allocator.dupe(u8, parts.next().?);

    var rules = std.ArrayList(Rule).init(allocator);

    while (parts.next()) |rule_s| {
        try rules.append(try parseRule(allocator, rule_s));
    }

    return .{
        .label = label,
        .rules = rules,
    };
}

fn printProgram(program: Program) void {
    std.debug.print("Program{{ .label = {s},", .{program.label});
    std.debug.print(" .rules = {{", .{});
    for (program.rules.items) |rule| {
        std.debug.print("{},", .{rule});
    }

    std.debug.print("}} }}\n", .{});
}

const Input = struct {
    x: u32 = 0,
    m: u32 = 0,
    a: u32 = 0,
    s: u32 = 0,
};

fn parseInput(line: []const u8) !Input {
    var input = Input{};
    var parts = std.mem.tokenizeAny(u8, line, "{},");

    while (parts.next()) |part| {
        var pp = std.mem.splitScalar(u8, part, '=');
        const k = pp.next().?;
        const v = try std.fmt.parseUnsigned(u32, pp.next().?, 10);

        switch (k[0]) {
            'x' => {
                input.x = v;
            },
            'm' => {
                input.m = v;
            },
            'a' => {
                input.a = v;
            },
            's' => {
                input.s = v;
            },
            else => unreachable,
        }
    }

    return input;
}

fn fromInput(input: Input, k: u8) u32 {
    return switch (k) {
        'x' => input.x,
        'm' => input.m,
        'a' => input.a,
        's' => input.s,
        else => unreachable,
    };
}

fn matchRule(rule: Rule, input: Input) bool {
    return switch (rule.condition) {
        .e => true,
        .lt => |c| fromInput(input, c.v) < c.l,
        .gt => |c| fromInput(input, c.v) > c.l,
    };
}

fn isAcceptedInput(programs: std.StringHashMap(Program), input: Input) bool {
    var program = programs.get("in").?;

    while (true) {
        for (program.rules.items) |rule| {
            if (matchRule(rule, input)) {
                switch (rule.target) {
                    .accept => return true,
                    .reject => return false,
                    .jump => |jump| {
                        program = programs.get(jump).?;
                        break;
                    },
                }
            }
        }
    }
    unreachable;
}

const Interval = struct {
    min: u32,
    max: u32,
};

const EMPTY_INTERVAL: Interval = .{
    .min = 10,
    .max = 0,
};

const IntervalInput = struct {
    x: Interval,
    m: Interval,
    a: Interval,
    s: Interval,
};

const EMPTY_INTERVAL_INPUT = IntervalInput{
    .x = EMPTY_INTERVAL,
    .m = EMPTY_INTERVAL,
    .a = EMPTY_INTERVAL,
    .s = EMPTY_INTERVAL,
};

fn matchesRule(input: IntervalInput, condition: Condition) IntervalInput {
    var new_input = input;
    switch (condition) {
        .e => {
            return input;
        },
        .gt => |c| {
            switch (c.v) {
                'x' => {
                    new_input.x.min = @max(c.l + 1, new_input.x.min);
                },
                'm' => {
                    new_input.m.min = @max(c.l + 1, new_input.m.min);
                },
                'a' => {
                    new_input.a.min = @max(c.l + 1, new_input.a.min);
                },
                's' => {
                    new_input.s.min = @max(c.l + 1, new_input.s.min);
                },
                else => unreachable,
            }
        },
        .lt => |c| {
            switch (c.v) {
                'x' => {
                    new_input.x.max = @min(c.l - 1, new_input.x.max);
                },
                'm' => {
                    new_input.m.max = @min(c.l - 1, new_input.m.max);
                },
                'a' => {
                    new_input.a.max = @min(c.l - 1, new_input.a.max);
                },
                's' => {
                    new_input.s.max = @min(c.l - 1, new_input.s.max);
                },
                else => unreachable,
            }
        },
    }
    return new_input;
}

fn notMatchesRule(input: IntervalInput, condition: Condition) IntervalInput {
    var new_input = input;
    switch (condition) {
        .e => {
            return EMPTY_INTERVAL_INPUT;
        },
        .gt => |c| {
            switch (c.v) {
                'x' => {
                    new_input.x.max = @min(c.l, new_input.x.max);
                },
                'm' => {
                    new_input.m.max = @min(c.l, new_input.m.max);
                },
                'a' => {
                    new_input.a.max = @min(c.l, new_input.a.max);
                },
                's' => {
                    new_input.s.max = @min(c.l, new_input.s.max);
                },
                else => unreachable,
            }
        },
        .lt => |c| {
            switch (c.v) {
                'x' => {
                    new_input.x.min = @max(c.l, new_input.x.min);
                },
                'm' => {
                    new_input.m.min = @max(c.l, new_input.m.min);
                },
                'a' => {
                    new_input.a.min = @max(c.l, new_input.a.min);
                },
                's' => {
                    new_input.s.min = @max(c.l, new_input.s.min);
                },
                else => unreachable,
            }
        },
    }
    return new_input;
}

fn isPossible(input: IntervalInput) bool {
    if (input.x.min > input.x.max) return false;
    if (input.a.min > input.a.max) return false;
    if (input.s.min > input.s.max) return false;
    if (input.m.min > input.m.max) return false;
    return true;
}

fn executeParallel(programs: std.StringHashMap(Program), key: []const u8, input: IntervalInput, discovered_intervals: *std.ArrayList(IntervalInput)) error{OutOfMemory}!void {
    if (!isPossible(input)) {
        return;
    }

    var current_input = input;

    const program = programs.get(key).?;

    for (program.rules.items) |rule| {
        const matches_input = matchesRule(current_input, rule.condition);
        const not_matches_input = notMatchesRule(current_input, rule.condition);
        switch (rule.target) {
            .accept => try discovered_intervals.append(matches_input),
            .reject => {},
            .jump => |jump| {
                try executeParallel(programs, jump, matches_input, discovered_intervals);
            },
        }
        current_input = not_matches_input;
    }
}

pub fn solve(base_allocator: std.mem.Allocator, file: std.fs.File) anyerror!bp.AoCResult {
    var arena = std.heap.ArenaAllocator.init(base_allocator);
    defer arena.deinit();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1000]u8 = undefined;

    const allocator = arena.allocator();
    var programs = std.StringHashMap(Program).init(allocator);

    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (line.len == 0) {
            break;
        }

        const program = try parseProgram(allocator, line);
        try programs.put(program.label, program);
    }

    var inputs = std.ArrayList(Input).init(allocator);
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try inputs.append(try parseInput(line));
    }

    var part1: u64 = 0;
    for (inputs.items) |input| {
        if (isAcceptedInput(programs, input)) {
            part1 += input.x + input.m + input.a + input.s;
        }
    }

    var discovered_intervals = std.ArrayList(IntervalInput).init(allocator);

    try executeParallel(programs, "in", .{
        .x = .{
            .min = 1,
            .max = 4000,
        },
        .m = .{
            .min = 1,
            .max = 4000,
        },
        .a = .{
            .min = 1,
            .max = 4000,
        },
        .s = .{
            .min = 1,
            .max = 4000,
        },
    }, &discovered_intervals);

    var part2: u64 = 0;

    for (discovered_intervals.items) |int| {
        part2 += @as(u64, 1) * (int.x.max - int.x.min + 1) * (int.m.max - int.m.min + 1) * (int.a.max - int.a.min + 1) * (int.s.max - int.s.min + 1);
    }

    return bp.AoCResult{ .part1 = part1, .part2 = part2 };
}
