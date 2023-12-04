const std = @import("std");

const bp = @import("../../boilerplate.zig");

const CellKind = enum { Space, Digit, Symbol };

const Cell = struct { kind: CellKind = CellKind.Space, value: u8 = '.', symbolNear: ?*Cell = null };

const Row = std.ArrayList(Cell);
const Map = std.ArrayList(Row);

const PartNo = struct { no: u64, symbolNear: *Cell };

fn u8ToKind(c: u8) CellKind {
    if (c == '.') return CellKind.Space;
    if ('0' <= c and c <= '9') return CellKind.Digit;
    return CellKind.Symbol;
}

fn findPartsInRow(allocator: std.mem.Allocator, row: Row) !std.ArrayList(PartNo) {
    var parts = std.ArrayList(PartNo).init(allocator);

    var numCandidate: u64 = 0;
    var nearSymbol: ?*Cell = null;

    for (row.items) |cell| {
        if (cell.kind == CellKind.Digit) {
            nearSymbol = cell.symbolNear orelse nearSymbol;
            numCandidate = numCandidate * 10 + (cell.value - '0');
        } else {
            if (nearSymbol) |symbol| {
                try parts.append(.{ .no = numCandidate, .symbolNear = symbol });
            }
            nearSymbol = null;
            numCandidate = 0;
        }
    }

    return parts;
}

fn sumParts(partNos: std.ArrayList(PartNo)) !u64 {
    var total: u64 = 0;

    for (partNos.items) |partNo| {
        total += partNo.no;
    }

    return total;
}

fn analyzeMap(allocator: std.mem.Allocator, map: Map) !bp.AoCResult {
    var sumPartNos: u64 = 0;
    var gearMap = std.AutoHashMap(*Cell, struct { count: u8 = 0, product: u64 = 1 }).init(allocator);
    defer gearMap.deinit();

    for (map.items) |row| {
        const parts = try findPartsInRow(allocator, row);
        defer parts.deinit();
        for (parts.items) |part| {
            sumPartNos += part.no;
            if (part.symbolNear.value == '*') {
                var entry = &try gearMap.getOrPutValue(part.symbolNear, .{});
                if (entry.value_ptr.count < 2) {
                    entry.value_ptr.product *= part.no;
                }
                entry.value_ptr.count += 1;
            }
        }
    }

    var iter = gearMap.valueIterator();

    var sumGearRatioProducts: u64 = 0;
    while (iter.next()) |value| {
        if (value.count == 2) {
            sumGearRatioProducts += value.product;
        }
    }

    return .{ .part1 = sumPartNos, .part2 = sumGearRatioProducts };
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

pub fn solve(file: std.fs.File) anyerror!bp.AoCResult {
    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    var buf: [1000]u8 = undefined;
    var rowIdx: u16 = 1;

    var mapOpt: ?Map = null;
    defer {
        if (mapOpt) |mapR| {
            for (mapR.items) |row| {
                row.deinit();
            }
            mapR.deinit();
        }
    }
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| : (rowIdx += 1) {
        if (mapOpt == null) {
            mapOpt = @TypeOf(mapOpt.?).init(allocator);
            var row = try Row.initCapacity(allocator, line.len + 2);
            try row.resize(line.len + 2);
            for (0..row.items.len) |i| {
                row.items[i] = Cell{};
            }
            try mapOpt.?.append(row);
            row = try Row.initCapacity(allocator, line.len + 2);
            try row.resize(line.len + 2);
            for (0..row.items.len) |i| {
                row.items[i] = Cell{};
            }
            try mapOpt.?.append(row);
        }

        var map = &mapOpt.?;
        var newRow = try Row.initCapacity(allocator, line.len + 2);
        try newRow.resize(line.len + 2);
        for (0..newRow.items.len) |i| {
            newRow.items[i] = Cell{};
        }
        try map.append(newRow);

        for (line, 1..) |c, colIdx| {
            const row = map.items[rowIdx];
            const cell = &row.items[colIdx];
            cell.kind = u8ToKind(c);
            cell.value = c;

            if (cell.kind == CellKind.Symbol) {
                for (0..3) |rowOff| {
                    for (0..3) |colOff| {
                        map.items[rowIdx + rowOff - 1].items[colIdx + colOff - 1].symbolNear = cell;
                    }
                }
            }
        }
    }

    return try analyzeMap(allocator, mapOpt.?);
}
