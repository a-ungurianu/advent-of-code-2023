const std = @import("std");

pub fn every(comptime T: type, array: []const T, pred: fn (val: T) bool) bool {
    for (array) |item| {
        if (!pred(item)) {
            return false;
        }
    }
    return true;
}

fn ReverseIterator(comptime T: type) type {
    return struct {
        buffer: []const T,
        idx: usize,
        const Self = @This();
        pub fn next(self: *Self) ?T {
            if (self.idx == 0) return null;
            self.idx -= 1;
            return self.buffer[self.idx];
        }
    };
}

pub fn reverseIterator(comptime T: type, array: []const T) ReverseIterator(T) {
    return .{
        .buffer = array,
        .idx = array.len,
    };
}
