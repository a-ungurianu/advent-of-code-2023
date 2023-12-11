const std = @import("std");

const bp = @import("../../boilerplate.zig");

fn HashSet(comptime T: type) type {
    return std.AutoHashMap(T, void);
}

const NumberSet = HashSet(u8);

const Card = struct {
    winning: NumberSet,
    scratched: NumberSet,

    const Self = @This();
    pub fn deinit(self: *Self) void {
        self.scratched.deinit();
        self.winning.deinit();
    }
};

fn parseNumberSet(allocator: std.mem.Allocator, buf: []const u8) !NumberSet {
    var tokens = std.mem.tokenizeScalar(u8, buf, ' ');

    var numbers = NumberSet.init(allocator);
    errdefer numbers.deinit();

    while (tokens.next()) |token| {
        try numbers.put(try std.fmt.parseUnsigned(u8, token, 10), {});
    }

    return numbers;
}

fn parseCard(allocator: std.mem.Allocator, line: []const u8) !Card {
    var parts = std.mem.splitAny(u8, line, ":|");

    _ = parts.next();

    return .{
        .winning = try parseNumberSet(allocator, parts.next().?),
        .scratched = try parseNumberSet(allocator, parts.next().?),
    };
}

fn setIntesection(comptime T: type, allocator: std.mem.Allocator, set_a: HashSet(T), set_b: HashSet(T)) !HashSet(T) {
    var intersect = HashSet(T).init(allocator);
    errdefer intersect.deinit();

    var it = set_a.keyIterator();

    while (it.next()) |k| {
        if (set_b.contains(k.*)) {
            try intersect.put(k.*, {});
        }
    }
    return intersect;
}
fn printCard(card: Card) void {
    std.debug.print("Card{{ winning={{", .{});

    var it = card.winning.keyIterator();

    while (it.next()) |key| {
        std.debug.print(" {}", .{key.*});
    }
    std.debug.print("}}, scratched={{", .{});
    it = card.scratched.keyIterator();
    while (it.next()) |key| {
        std.debug.print(" {}", .{key.*});
    }
    std.debug.print("}} }}\n", .{});
}

pub fn solve(allocator: std.mem.Allocator, file: std.fs.File) anyerror!bp.AoCResult {
    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1000]u8 = undefined;
    var row_idx: u16 = 1;

    var part1: u64 = 0;

    var card_multipliers = std.ArrayList(struct { matches: usize, count: usize }).init(allocator);
    defer card_multipliers.deinit();

    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| : (row_idx += 1) {
        var card = try parseCard(allocator, line);
        defer card.deinit();

        var picked_winners = try setIntesection(u8, allocator, card.winning, card.scratched);
        defer picked_winners.deinit();

        if (picked_winners.count() > 0) {
            part1 += std.math.pow(u64, 2, picked_winners.count() - 1);
        }
        try card_multipliers.append(.{ .matches = picked_winners.count(), .count = 1 });
    }

    var part2: u64 = 0;
    for (0..card_multipliers.items.len) |idx| {
        const card_mult = &card_multipliers.items[idx];
        part2 += card_mult.count;
        for ((idx + 1)..@max(idx + 1, @min(idx + card_mult.matches + 1, card_multipliers.items.len))) |i| {
            card_multipliers.items[i].count += card_mult.count;
        }
    }

    return .{ .part1 = part1, .part2 = part2 };
}
