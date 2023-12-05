const std = @import("std");

const bp = @import("../../boilerplate.zig");

const CellKind = enum { Space, Digit, Symbol };

const Cell = struct { kind: CellKind = CellKind.Space, value: u8 = '.', symbol_near: ?*Cell = null };

const Row = std.ArrayList(Cell);
const Map = std.ArrayList(Row);

const PartNo = struct { no: u64, symbol_near: *Cell };

fn u8ToKind(c: u8) CellKind {
    if (c == '.') return CellKind.Space;
    if ('0' <= c and c <= '9') return CellKind.Digit;
    return CellKind.Symbol;
}

fn findPartsInRow(allocator: std.mem.Allocator, row: Row) !std.ArrayList(PartNo) {
    var parts = std.ArrayList(PartNo).init(allocator);
    errdefer parts.deinit();

    var num_candidate: u64 = 0;
    var near_symbol: ?*Cell = null;

    for (row.items) |cell| {
        if (cell.kind == CellKind.Digit) {
            near_symbol = cell.symbol_near orelse near_symbol;
            num_candidate = num_candidate * 10 + (cell.value - '0');
        } else {
            if (near_symbol) |symbol| {
                try parts.append(.{ .no = num_candidate, .symbol_near = symbol });
            }
            near_symbol = null;
            num_candidate = 0;
        }
    }

    return parts;
}

fn sumParts(part_nos: std.ArrayList(PartNo)) !u64 {
    var total: u64 = 0;

    for (part_nos.items) |partNo| {
        total += partNo.no;
    }

    return total;
}

fn analyzeMap(allocator: std.mem.Allocator, map: Map) !bp.AoCResult {
    var sum_part_nos: u64 = 0;
    var gear_map = std.AutoHashMap(*Cell, struct { count: u8 = 0, product: u64 = 1 }).init(allocator);
    defer gear_map.deinit();

    for (map.items) |row| {
        const parts = try findPartsInRow(allocator, row);
        defer parts.deinit();
        for (parts.items) |part| {
            sum_part_nos += part.no;
            if (part.symbol_near.value == '*') {
                var entry = &try gear_map.getOrPutValue(part.symbol_near, .{});
                if (entry.value_ptr.count < 2) {
                    entry.value_ptr.product *= part.no;
                }
                entry.value_ptr.count += 1;
            }
        }
    }

    var iter = gear_map.valueIterator();

    var sum_gear_ratio_products: u64 = 0;
    while (iter.next()) |value| {
        if (value.count == 2) {
            sum_gear_ratio_products += value.product;
        }
    }

    return .{ .part1 = sum_part_nos, .part2 = sum_gear_ratio_products };
}

fn debugPrint(map: Map) void {
    for (map.items) |row| {
        for (row.items) |c| {
            if (c.kind == CellKind.Symbol) {
                std.debug.print("\x1b[36m{c}\x1b[0m", .{c.value});
            } else {
                if (c.symbolNear) |_| {
                    std.debug.print("\x1b[35m{c}\x1b[0m", .{c.value});
                } else {
                    std.debug.print("{c}", .{c.value});
                }
            }
        }
        std.debug.print("\n", .{});
    }
}

pub fn solve(allocator: std.mem.Allocator, file: std.fs.File) anyerror!bp.AoCResult {
    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1000]u8 = undefined;
    var row_idx: u16 = 1;

    var map_opt: ?Map = null;
    defer {
        if (map_opt) |map| {
            for (map.items) |row| {
                row.deinit();
            }
            map.deinit();
        }
    }
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| : (row_idx += 1) {
        if (map_opt == null) {
            map_opt = @TypeOf(map_opt.?).init(allocator);
            var row = try Row.initCapacity(allocator, line.len + 2);
            try row.resize(line.len + 2);
            for (0..row.items.len) |i| {
                row.items[i] = Cell{};
            }
            try map_opt.?.append(row);
            row = try Row.initCapacity(allocator, line.len + 2);
            try row.resize(line.len + 2);
            for (0..row.items.len) |i| {
                row.items[i] = Cell{};
            }
            try map_opt.?.append(row);
        }

        var map = &map_opt.?;
        var new_row = try Row.initCapacity(allocator, line.len + 2);
        try new_row.resize(line.len + 2);
        for (0..new_row.items.len) |i| {
            new_row.items[i] = Cell{};
        }
        try map.append(new_row);

        for (line, 1..) |c, colIdx| {
            const row = map.items[row_idx];
            const cell = &row.items[colIdx];
            cell.kind = u8ToKind(c);
            cell.value = c;

            if (cell.kind == CellKind.Symbol) {
                for (0..3) |rowOff| {
                    for (0..3) |colOff| {
                        map.items[row_idx + rowOff - 1].items[colIdx + colOff - 1].symbol_near = cell;
                    }
                }
            }
        }
    }

    return try analyzeMap(allocator, map_opt.?);
}
