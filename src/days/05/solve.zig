const std = @import("std");

const parse = @import("../../common/parse.zig");
const bp = @import("../../boilerplate.zig");

fn parseSeeds(allocator: std.mem.Allocator, line: []u8) !std.ArrayList(u64) {
    var parts = std.mem.splitScalar(u8, line, ':');

    _ = parts.next();

    var numbers_s = parts.next().?;

    return try parse.numbers(u64, allocator, numbers_s, " ");
}

const RangeMapping = struct {
    start_dest: u64,
    start_source: u64,
    range_size: u64,

    const Self = @This();

    fn sourceRange(this: Self) Range {
        return .{ .start = this.start_source, .size = this.range_size };
    }

    fn offset(this: Self) i64 {
        return @as(i64, @intCast(this.start_dest)) - @as(i64, @intCast(this.start_source));
    }
};

fn parseRangeMapping(line: []u8) !RangeMapping {
    var parts = std.mem.tokenizeScalar(u8, line, ' ');

    const start_dest = try std.fmt.parseUnsigned(u64, parts.next().?, 10);
    const start_source = try std.fmt.parseUnsigned(u64, parts.next().?, 10);
    const range_size = try std.fmt.parseUnsigned(u64, parts.next().?, 10);
    return .{
        .start_dest = start_dest,
        .start_source = start_source,
        .range_size = range_size,
    };
}
const CategoryMap = std.ArrayList(RangeMapping);

fn printCategoryMap(category_map: CategoryMap) void {
    for (category_map.items) |range_mapping| {
        std.debug.print("    {} {} {}\n", .{ range_mapping.start_dest, range_mapping.start_source, range_mapping.range_size });
    }
}

fn applyRangeMapping(item: u64, range_mapping: RangeMapping) ?u64 {
    if (range_mapping.start_source <= item and item < range_mapping.start_source + range_mapping.range_size) {
        return @intCast(@as(i64, @intCast(item)) + range_mapping.offset());
    }
    return null;
}

fn applyCategoryMap(item: u64, category_map: CategoryMap) u64 {
    for (category_map.items) |range_mapping| {
        if (applyRangeMapping(item, range_mapping)) |new_item| {
            return new_item;
        }
    }
    return item;
}

const Range = struct {
    start: u64,
    size: u64,
    const Self = @This();

    fn end(self: Self) u64 {
        return self.start + self.size;
    }
};

fn seedsToRanges(allocator: std.mem.Allocator, seeds: std.ArrayList(u64)) !std.ArrayList(Range) {
    var ranges = std.ArrayList(Range).init(allocator);
    errdefer ranges.deinit();

    var idx: usize = 0;
    while (idx < seeds.items.len) : (idx += 2) {
        try ranges.append(.{
            .start = seeds.items[idx],
            .size = seeds.items[idx + 1],
        });
    }
    return ranges;
}

const EdgeKind = enum {
    seed,
    mapping,
};

const Edge = struct {
    value: u64,
    is_start: bool,
    source: union(EdgeKind) {
        seed: Range,
        mapping: RangeMapping,
    },

    const Self = @This();

    fn compare(context: void, a: Self, b: Self) bool {
        if (a.value == b.value) {
            return !a.is_start;
        }
        return std.sort.asc(u64)(context, a.value, b.value);
    }
};

fn applyMapToRanges(allocator: std.mem.Allocator, category_map: CategoryMap, ranges: *std.ArrayList(Range)) !void {
    var edges = std.ArrayList(Edge).init(allocator);
    defer edges.deinit();

    for (ranges.items) |range| {
        try edges.append(.{ .value = range.start, .is_start = true, .source = .{ .seed = range } });
        try edges.append(.{ .value = range.end(), .is_start = false, .source = .{ .seed = range } });
    }
    for (category_map.items) |range_mapping| {
        const range = range_mapping.sourceRange();
        try edges.append(.{ .value = range.start, .is_start = true, .source = .{ .mapping = range_mapping } });
        try edges.append(.{ .value = range.end(), .is_start = false, .source = .{ .mapping = range_mapping } });
    }

    ranges.clearRetainingCapacity();
    std.sort.pdq(Edge, edges.items, {}, Edge.compare);

    var lastEdge: Edge = edges.items[0];
    var inRange = @as(EdgeKind, lastEdge.source) == EdgeKind.seed;
    var lastMapping: ?RangeMapping = if (@as(EdgeKind, lastEdge.source) == EdgeKind.mapping) lastEdge.source.mapping else null;

    for (edges.items[1..]) |edge| {
        if (inRange and edge.value - lastEdge.value > 0) {
            var range = Range{
                .start = lastEdge.value,
                .size = edge.value - lastEdge.value,
            };
            if (lastMapping) |mapping| {
                range.start = @as(u64, @intCast(@as(i64, @intCast(range.start)) + mapping.offset()));
            }
            try ranges.append(range);
        }

        if (edge.is_start) {
            switch (edge.source) {
                EdgeKind.mapping => |mapping| {
                    lastMapping = mapping;
                },
                EdgeKind.seed => {
                    inRange = true;
                },
            }
        } else {
            switch (edge.source) {
                EdgeKind.mapping => {
                    lastMapping = null;
                },
                EdgeKind.seed => {
                    inRange = false;
                },
            }
        }
        lastEdge = edge;
    }
}

pub fn solve(allocator: std.mem.Allocator, file: std.fs.File) anyerror!bp.AoCResult {
    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1000]u8 = undefined;

    const seeds = try parseSeeds(allocator, (try in_stream.readUntilDelimiterOrEof(&buf, '\n')).?);
    defer seeds.deinit();

    var ranges = try seedsToRanges(allocator, seeds);
    defer ranges.deinit();

    var categoryMaps = std.ArrayList(CategoryMap).init(allocator);
    defer {
        for (categoryMaps.items) |categoryMap| {
            categoryMap.deinit();
        }
        categoryMaps.deinit();
    }

    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (line.len == 0) continue;
        if (line[line.len - 1] == ':') {
            // this is a category map header
            var newMap = CategoryMap.init(allocator);
            errdefer newMap.deinit();
            try categoryMaps.append(newMap);
        } else {
            // actual range
            var lastMap = &categoryMaps.items[categoryMaps.items.len - 1];
            try lastMap.append(try parseRangeMapping(line));
        }
    }

    for (seeds.items) |*seed| {
        for (categoryMaps.items) |category_map| {
            seed.* = applyCategoryMap(seed.*, category_map);
        }
    }

    var minValue = seeds.items[0];

    for (seeds.items) |seed| {
        minValue = @min(minValue, seed);
    }
    for (categoryMaps.items) |category_map| {
        try applyMapToRanges(allocator, category_map, &ranges);
    }

    var minRangeSeed = ranges.items[0].start;
    for (ranges.items) |range| {
        minRangeSeed = @min(minRangeSeed, range.start);
    }

    return .{ .part1 = minValue, .part2 = minRangeSeed };
}
