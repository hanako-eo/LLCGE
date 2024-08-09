const std = @import("std");

const Context = @import("./context.zig");

const types_zig = @import("../utils/types.zig");
const ExpectationSimple = types_zig.ExpectationSimple;
const Expectation = types_zig.Expectation;
const Result = types_zig.Result;

pub fn StringParser(comptime S: type) type {
    return Parser([]const u8, S);
}
pub fn Parser(comptime T: type, comptime S: type) type {
    return struct {
        state: S,
        lambda: *const fn (*S, *Context) Result(T, ParseError),

        const Self = @This();

        pub fn init(state: S, lambda: fn (*S, *Context) Result(T, ParseError)) Self {
            return Self{ .lambda = lambda, .state = state };
        }

        pub fn runWithContext(self: *Self, context: *Context) Result(T, ParseError) {
            return self.lambda(&self.state, context);
        }

        pub fn runWithoutCommit(self: *Self, input: []const u8) struct { Result(T, ParseError), Context } {
            var context = Context.init(input);

            return .{ self.runWithContext(&context), context };
        }

        pub fn run(self: *Self, input: []const u8) struct { Result(T, ParseError), Context } {
            const result, var context = self.runWithoutCommit(input);
            context.commit();
            return .{ result, context };
        }

        // modifiers
        pub fn map(self: Self, comptime U: type, lambda: *const fn (T) U) Parser(U, MapState(T, U, S)) {
            const state = MapState(T, U, S){ .map = lambda, .parser = self };
            return Parser(U, MapState(T, U, S)).init(state, MapState(T, U, S).process);
        }
    };
}

pub const ParseError = struct { cursor: usize, len: usize, input: []const u8, kind: ParseErrorKind };

pub const ParseErrorKind = union(enum) {
    tag: []const u8,
    one_of: Expectation([]const u8, u8),
    char: ExpectationSimple(u8),
};

fn MapState(comptime T: type, comptime U: type, comptime S: type) type {
    return struct {
        map: *const fn (T) U,
        parser: Parser(T, S),

        const Self = @This();

        pub fn process(self: *Self, context: *Context) Result(U, ParseError) {
            const result = self.parser.runWithContext(context);
            return switch (result) {
                .err => |err| .{ .err = err },
                .ok => |value| .{ .ok = self.map(value) },
            };
        }
    };
}

const testing = std.testing;
test "import parsing tests" {
    _ = @import("./bytes.zig");
    _ = @import("./chars.zig");
}

const Hello = struct {};
fn call_map(_: []const u8) Hello {
    return Hello{};
}

test "change the content a the token" {
    const tag = @import("./bytes.zig").tag;

    var parser = tag("hello");
    var map_parser = parser.map(Hello, call_map);

    const result, const context = parser.run("hello");
    try testing.expectEqualDeep(Result([]const u8, ParseError){ .ok = "hello" }, result);
    try testing.expectEqual(context.dirty_cursor, context.cursor);

    const result2, const context2 = map_parser.run("hello");
    try testing.expectEqualDeep(Result(Hello, ParseError){ .ok = Hello{} }, result2);
    try testing.expectEqual(context2.dirty_cursor, context2.cursor);
}
