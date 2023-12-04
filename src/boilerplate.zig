const std = @import("std");

pub const AoCResult = struct { part1: u64, part2: u64 };

pub const Solver = fn (file: std.fs.File) anyerror!AoCResult;
