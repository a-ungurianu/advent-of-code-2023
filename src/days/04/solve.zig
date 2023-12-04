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

fn setIntesection(comptime T: type, allocator: std.mem.Allocator, setA: HashSet(T), setB: HashSet(T)) !HashSet(T) {
    var intersect = HashSet(T).init(allocator);
    errdefer intersect.deinit();

    var it = setA.keyIterator();

    while (it.next()) |k| {
        if (setB.contains(k.*)) {
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
    var rowIdx: u16 = 1;

    var part1: u64 = 0;

    var cardMultipliers = std.ArrayList(struct { matches: usize, count: usize }).init(allocator);
    defer cardMultipliers.deinit();

    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| : (rowIdx += 1) {
        var card = try parseCard(allocator, line);
        defer card.deinit();

        var pickedWinners = try setIntesection(u8, allocator, card.winning, card.scratched);
        defer pickedWinners.deinit();

        if (pickedWinners.count() > 0) {
            part1 += std.math.pow(u64, 2, pickedWinners.count() - 1);
        }
        try cardMultipliers.append(.{ .matches = pickedWinners.count(), .count = 1 });
    }

    var part2: u64 = 0;
    for (0..cardMultipliers.items.len) |idx| {
        var cardMult = &cardMultipliers.items[idx];
        part2 += cardMult.count;
        for ((idx + 1)..@max(idx + 1, @min(idx + cardMult.matches + 1, cardMultipliers.items.len))) |i| {
            cardMultipliers.items[i].count += cardMult.count;
        }
    }

    return .{ .part1 = part1, .part2 = part2 };
}
