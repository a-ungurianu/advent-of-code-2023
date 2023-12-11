const std = @import("std");

const bp = @import("../../boilerplate.zig");

fn parseCard(card: u8) u8 {
    if ('2' <= card and card <= '9') {
        return card - '0';
    }
    return switch (card) {
        'T' => 10,
        'J' => 11,
        'Q' => 12,
        'K' => 13,
        'A' => 14,
        else => unreachable,
    };
}

const Hand = [5]u8;

fn parseHand(line: []const u8) Hand {
    var hand: Hand = undefined;

    for (line, 0..) |c, i| {
        hand[i] = parseCard(c);
    }
    return hand;
}

const HandPower = enum {
    HighCard,
    OnePair,
    TwoPair,
    ThreeOfAKind,
    FullHouse,
    FourOfAKind,
    FiveOfAKind,
};

const Game = struct {
    hand: Hand,
    bid: u32,
    power: HandPower,
    const Self = @This();
    fn compareAsc(context: void, a: Self, b: Self) bool {
        if (a.power != b.power) {
            return std.sort.asc(@TypeOf(@intFromEnum(HandPower.FiveOfAKind)))(context, @intFromEnum(a.power), @intFromEnum(b.power));
        }

        for (a.hand, b.hand) |ac, bc| {
            if (ac != bc) {
                return std.sort.asc(u8)(context, ac, bc);
            }
        }
        return true;
    }
    fn compareAscJ(context: void, a: Self, b: Self) bool {
        if (a.power != b.power) {
            return std.sort.asc(@TypeOf(@intFromEnum(HandPower.FiveOfAKind)))(context, @intFromEnum(a.power), @intFromEnum(b.power));
        }

        for (a.hand, b.hand) |ac, bc| {
            if (ac != bc) {
                return std.sort.asc(u8)(
                    context,
                    if (ac == 11) 0 else ac,
                    if (bc == 11) 0 else bc,
                );
            }
        }
        return true;
    }
};

fn calculateHandPower(hand: Hand, countJokers: bool) HandPower {
    var cardCounts = [_]u8{0} ** 14;
    var jokerCount: u8 = 0;

    for (hand) |c| {
        if (c == 11 and countJokers) {
            jokerCount += 1;
        } else {
            cardCounts[c - 1] += 1;
        }
    }
    var pairCount: u8 = 0;
    var threeCount: u8 = 0;
    std.sort.pdq(u8, &cardCounts, {}, std.sort.desc(u8));

    for (cardCounts) |cc| {
        if (cc + jokerCount == 5) {
            return .FiveOfAKind;
        }
        if (cc + jokerCount == 4) {
            return .FourOfAKind;
        }
        if (cc == 3) {
            threeCount += 1;
        }
        if (cc == 2) {
            pairCount += 1;
        }
    }

    if (threeCount > 0 and pairCount > 0) {
        return .FullHouse;
    }

    if (pairCount == 2 and jokerCount > 0) {
        return .FullHouse;
    }

    if (threeCount > 0) {
        return .ThreeOfAKind;
    }

    if (pairCount > 0 and jokerCount > 0) {
        return .ThreeOfAKind;
    }

    if (pairCount == 2) {
        return .TwoPair;
    }
    if (pairCount == 1) {
        return .OnePair;
    }

    if (jokerCount == 0) {
        return .HighCard;
    }

    if (jokerCount == 1) {
        return .OnePair;
    }
    if (jokerCount == 2) {
        return .ThreeOfAKind;
    }

    return .HighCard;
}

test "calculateHandWithJokers" {
    const TestCase = struct {
        hand: [5]u8,
        result: HandPower,
    };

    const test_cases = [_]TestCase{
        .{ .hand = "23456".*, .result = .HighCard },
        .{ .hand = "2345J".*, .result = .OnePair },
        .{ .hand = "2233J".*, .result = .FullHouse },
        .{ .hand = "2333J".*, .result = .FourOfAKind },
        .{ .hand = "3333J".*, .result = .FiveOfAKind },
        .{ .hand = "223JJ".*, .result = .FourOfAKind },
        .{ .hand = "JJJJJ".*, .result = .FiveOfAKind },
        .{ .hand = "JJ3JJ".*, .result = .FiveOfAKind },
        .{ .hand = "KKKKK".*, .result = .FiveOfAKind },
        .{ .hand = "KKKQQ".*, .result = .FullHouse },
        .{ .hand = "KQQJJ".*, .result = .FourOfAKind },
        .{ .hand = "2J5J2".*, .result = .FourOfAKind },
        .{ .hand = "5A66J".*, .result = .ThreeOfAKind },
        .{ .hand = "QJ828".*, .result = .ThreeOfAKind },
        .{ .hand = "TJTJQ".*, .result = .FourOfAKind },
    };

    for (test_cases) |test_case| {
        std.testing.expectEqual(test_case.result, calculateHandPower(parseHand(&test_case.hand), true)) catch |err| {
            std.debug.print("Failing for {s}\n", .{test_case.hand});
            return err;
        };
    }
}

fn parseGame(line: []const u8) !Game {
    var parts = std.mem.splitScalar(u8, line, ' ');

    const hand = parseHand(parts.next().?);

    const bid = try std.fmt.parseUnsigned(u32, parts.next().?, 10);

    return .{ .hand = hand, .bid = bid, .power = calculateHandPower(hand, false) };
}

pub fn solve(allocator: std.mem.Allocator, file: std.fs.File) anyerror!bp.AoCResult {
    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1000]u8 = undefined;

    var games = std.ArrayList(Game).init(allocator);
    defer games.deinit();

    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try games.append(try parseGame(line));
    }

    std.sort.pdq(Game, games.items, {}, Game.compareAsc);

    var part1: u64 = 0;

    for (games.items, 1..) |game, rank| {
        part1 += game.bid * rank;
    }

    for (games.items) |*game| {
        game.power = calculateHandPower(game.hand, true);
    }
    std.sort.pdq(Game, games.items, {}, Game.compareAscJ);

    var part2: u64 = 0;

    for (games.items, 1..) |game, rank| {
        part2 += game.bid * rank;
    }

    return .{ .part1 = part1, .part2 = part2 };
}
// 251906542
// 251582295
