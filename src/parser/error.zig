const std = @import("std");
const AllocatorError = std.mem.Allocator.Error;

const types_zig = @import("../utils/types.zig");
const ExpectationSimple = types_zig.ExpectationSimple;
const Expectation = types_zig.Expectation;
const Unexpectation = types_zig.Unexpectation;

pub fn ParseError(comptime K: type) type {
    return struct { cursor: usize, len: usize, input: []const u8, kind: ParseErrorKind(K) };
}

pub fn ParseErrorKind(comptime N: type) type {
    return union(enum) {
        tag: ExpectationSimple([]const u8),
        one_of: Expectation([]const u8, u8),
        unexpected: Unexpectation(u8),
        char: ExpectationSimple(u8),
        satisfy: []const u8,
        not_finished: void,
        finished: void,

        allocation_error: AllocatorError,

        not: Unexpectation(N),
    };
}
