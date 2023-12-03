const std = @import("std");

pub const AoCResult = struct { part1: u32, part2: u32 };

pub const Solver = fn (file: std.fs.File) anyerror!AoCResult;
