const std = @import("std");

const bp = @import("../../boilerplate.zig");

fn getSingleDigit(line: []u8, idx: usize) ?u32 {
    const c = line[idx];
    if ('0' <= c and c <= '9') {
        return c - '0';
    }
    return null;
}

const digits_spelled = [_][]const u8{
    "one",
    "two",
    "three",
    "four",
    "five",
    "six",
    "seven",
    "eight",
    "nine",
    "ten",
};

fn getDigitBetter(line: []u8, idx: usize) ?u32 {
    if (getSingleDigit(line, idx)) |digit| {
        return digit;
    }

    var digit_candidate: u8 = 1;
    while (digit_candidate <= 9) : (digit_candidate += 1) {
        const digit_spelled = digits_spelled[digit_candidate - 1];
        if (std.mem.eql(u8, line[idx..@min(line.len, idx + digit_spelled.len)], digit_spelled)) {
            return digit_candidate;
        }
    }
    return null;
}

const DigitFinder = fn (line: []u8, idx: usize) ?u32;

fn findFirstDigit(line: []u8, comptime get_digit: DigitFinder) u32 {
    var i: usize = 0;
    while (i < line.len) : (i += 1) {
        if (get_digit(line, i)) |digit| {
            return digit;
        }
    }
    unreachable;
}

fn findLastDigit(line: []u8, comptime get_digit: DigitFinder) u32 {
    var i = line.len;
    while (i > 0) : (i -= 1) {
        if (get_digit(line, i - 1)) |digit| {
            return digit;
        }
    }
    unreachable;
}

fn findCalibrationValue(line: []u8, comptime get_digit: DigitFinder) u32 {
    const first_digit = findFirstDigit(line, get_digit);
    const last_digit = findLastDigit(line, get_digit);

    return first_digit * 10 + last_digit;
}

pub fn solve(_: std.mem.Allocator, file: std.fs.File) anyerror!bp.AoCResult {
    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [200]u8 = undefined;

    var total: u32 = 0;
    var total2: u32 = 0;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        total += findCalibrationValue(line, getSingleDigit);
        total2 += findCalibrationValue(line, getDigitBetter);
    }

    return bp.AoCResult{ .part1 = total, .part2 = total2 };
}
