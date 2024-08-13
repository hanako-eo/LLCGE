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
        predicate: Unexpectation(u8),
        char: ExpectationSimple(u8),
        satisfy: []const u8,
        not_finished: void,
        finished: void,

        not: Unexpectation(N),
    };
}
