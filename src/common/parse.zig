const std = @import("std");

pub fn numbers(comptime T: type, allocator: std.mem.Allocator, buf: []const u8, separators: []const u8) !std.ArrayList(T) {
    var it = std.mem.tokenizeAny(u8, buf, separators);

    var arr = std.ArrayList(T).init(allocator);
    errdefer arr.deinit();

    while (it.next()) |nn| {
        try arr.append(try std.fmt.parseInt(T, nn, 10));
    }
    return arr;
}
