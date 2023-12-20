const std = @import("std");

const bp = @import("../../boilerplate.zig");

const ModuleMemoryKind = enum { ff, con, broadcaster };

const ModuleMemory = union(ModuleMemoryKind) {
    ff: bool,
    con: std.StringHashMap(bool),
    broadcaster: void,
};

const Module = struct {
    label: []u8,
    memory: ModuleMemory,
    downstream: std.ArrayList([]const u8),
};

fn parseModule(allocator: std.mem.Allocator, line: []const u8) !Module {
    var pair = std.mem.splitSequence(u8, line, " -> ");

    const left = pair.next().?;
    const right = pair.next().?;
    var module: Module = switch (left[0]) {
        '%' => .{
            .label = try allocator.dupe(u8, left[1..]),
            .memory = .{
                .ff = false,
            },
            .downstream = std.ArrayList([]const u8).init(allocator),
        },
        '&' => .{
            .label = try allocator.dupe(u8, left[1..]),
            .memory = .{
                .con = std.StringHashMap(bool).init(allocator),
            },
            .downstream = std.ArrayList([]const u8).init(allocator),
        },
        else => if (std.mem.eql(u8, left, "broadcaster")) .{
            .label = try allocator.dupe(u8, left),
            .memory = .{
                .broadcaster = {},
            },
            .downstream = std.ArrayList([]const u8).init(allocator),
        } else unreachable,
    };

    var downstreams = std.mem.tokenizeAny(u8, right, ", ");

    while (downstreams.next()) |downstream| {
        try module.downstream.append(try allocator.dupe(u8, downstream));
    }

    return module;
}

fn connectCons(modules: std.StringHashMap(Module)) !void {
    var vals = modules.valueIterator();

    while (vals.next()) |module| {
        for (module.downstream.items) |down_label| {
            if (modules.getPtr(down_label)) |down_module| {
                if (@as(ModuleMemoryKind, down_module.memory) == .con) {
                    try down_module.memory.con.put(module.label, false);
                }
            }
        }
    }
}

const Signal = struct {
    target: *Module,
    from: []const u8,
    signal: bool,
};

fn getConSignal(con: std.StringHashMap(bool)) bool {
    var res: bool = true;
    var vals = con.valueIterator();

    while (vals.next()) |val| {
        res = res and val.*;
    }

    return !res;
}

fn processSignal(
    signal: Signal,
) ?bool {
    const target = signal.target;

    switch (target.memory) {
        .ff => |ff| {
            if (signal.signal) {
                return null;
            } else {
                target.memory.ff = !ff;
                return target.memory.ff;
            }
        },
        .con => {
            target.memory.con.getPtr(signal.from).?.* = signal.signal;
            return getConSignal(target.memory.con);
        },
        .broadcaster => return null,
    }
}

fn printModule(module: Module) void {
    std.debug.print("{s} ", .{module.label});
    switch (module.memory) {
        .broadcaster => {
            std.debug.print("B", .{});
        },
        .ff => |ff| {
            std.debug.print("F[{s}]", .{if (ff) "H" else "L"});
        },
        .con => |con| {
            std.debug.print("C[", .{});
            var entries = con.iterator();
            while (entries.next()) |entry| {
                std.debug.print("{s}:{s},", .{ entry.key_ptr.*, if (entry.value_ptr.*) "H" else "L" });
            }
            std.debug.print("\x08]", .{});
        },
    }

    std.debug.print(" -> ", .{});

    for (module.downstream.items) |down| {
        std.debug.print("{s}, ", .{down});
    }

    std.debug.print("\x08\x08  \n", .{});
}

fn printModules(modules: std.StringHashMap(Module)) void {
    var vals = modules.valueIterator();

    while (vals.next()) |module| {
        printModule(module.*);
    }
}

fn lcm(a: u64, b: u64) u64 {
    return a * b / std.math.gcd(a, b);
}

pub fn solve(base_allocator: std.mem.Allocator, file: std.fs.File) anyerror!bp.AoCResult {
    var arena = std.heap.ArenaAllocator.init(base_allocator);
    defer arena.deinit();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1000]u8 = undefined;

    const allocator = arena.allocator();
    var modules = std.StringHashMap(Module).init(allocator);

    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const module = try parseModule(allocator, line);
        try modules.put(module.label, module);
    }

    try connectCons(modules);

    var q = std.fifo.LinearFifo(Signal, .{ .Dynamic = {} }).init(allocator);

    const broadcast = modules.get("broadcaster").?;

    const BUTTON_PUSHES = 1000;
    _ = BUTTON_PUSHES;

    var part1: ?u64 = null;
    var count_high: u64 = 0;
    var count_low: u64 = 0;

    var button_press_count: u64 = 0;

    var br: ?u64 = null;
    var lf: ?u64 = null;
    var rz: ?u64 = null;
    var fk: ?u64 = null;

    while (true) : (button_press_count += 1) {
        if (br != null and lf != null and rz != null and fk != null) {
            break;
        }

        if (button_press_count == 1000) {
            part1 = count_high * count_low;
        }
        // One for the button press
        count_low += 1;
        // std.debug.print("button -[ L ]-> broadcaster\n", .{});
        for (broadcast.downstream.items) |downstream_label| {
            try q.writeItem(.{
                .target = modules.getPtr(downstream_label).?,
                .from = broadcast.label,
                .signal = false,
            });
        }
        while (q.readItem()) |signal| {
            const output = processSignal(signal);

            if (signal.signal) {
                count_high += 1;
            } else {
                count_low += 1;
            }

            if (output) |output_signal| {
                for (signal.target.downstream.items) |downstream_label| {
                    if (std.mem.eql(u8, downstream_label, "br") and output_signal == false) {
                        br = button_press_count + 1;
                    }
                    if (std.mem.eql(u8, downstream_label, "lf") and output_signal == false) {
                        lf = button_press_count + 1;
                    }
                    if (std.mem.eql(u8, downstream_label, "rz") and output_signal == false) {
                        rz = button_press_count + 1;
                    }
                    if (std.mem.eql(u8, downstream_label, "fk") and output_signal == false) {
                        fk = button_press_count + 1;
                    }
                    if (modules.getPtr(downstream_label)) |target| {
                        try q.writeItem(.{
                            .target = target,
                            .from = signal.target.label,
                            .signal = output_signal,
                        });
                    } else {
                        if (output_signal) {
                            count_high += 1;
                        } else {
                            count_low += 1;
                        }
                        // std.debug.print(">{s} -[ {s} ]-> {s}\n", .{ signal.target.label, if (output_signal) "H" else "L", downstream_label });
                    }
                }
            }
        }
    }

    return bp.AoCResult{ .part1 = part1.?, .part2 = lcm(br.?, lcm(lf.?, lcm(rz.?, fk.?))) };
}
