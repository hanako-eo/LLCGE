const std = @import("std");

const Context = @import("./context.zig");

const types_zig = @import("../utils/types.zig");
const ExpectationSimple = types_zig.ExpectationSimple;
const Expectation = types_zig.Expectation;
const Unexpectation = types_zig.Unexpectation;
const Result = types_zig.Result;

fn getNotValue(comptime State: type) type {
    const state_info = @typeInfo(State);

    if (state_info != .Struct)
        @compileError("The state need to be a structure");

    const decls = state_info.Struct.decls;

    for (decls) |decl| {
        if (std.mem.eql(u8, decl.name, "NotValue"))
            return State.NotValue;
    }

    @compileError("The structure state need to have a const 'NotValue' (a type)");
}

pub fn StringParser(comptime S: type) type {
    return Parser([]const u8, S);
}
pub fn Parser(comptime T: type, comptime S: type) type {
    const NotValue = getNotValue(S);

    return struct {
        state: S,
        lambda: *const fn (S, *Context) Result(T, ParseError(NotValue)),

        const Self = @This();

        pub fn init(state: S, lambda: fn (S, *Context) Result(T, ParseError(NotValue))) Self {
            return Self{ .lambda = lambda, .state = state };
        }

        pub fn runWithContext(self: Self, context: *Context) Result(T, ParseError(NotValue)) {
            return self.lambda(self.state, context);
        }

        pub fn runWithoutCommit(self: Self, input: []const u8) struct { Result(T, ParseError(NotValue)), Context } {
            var context = Context.init(input);

            return .{ self.runWithContext(&context), context };
        }

        pub fn run(self: Self, input: []const u8) struct { Result(T, ParseError(NotValue)), Context } {
            const result, var context = self.runWithoutCommit(input);
            context.commit();
            return .{ result, context };
        }

        // modifiers
        pub fn map(self: Self, comptime U: type, lambda: *const fn (T) U) Parser(U, MapState(T, U, S)) {
            const state = MapState(T, U, S){ .map = lambda, .parser = self };
            return Parser(U, MapState(T, U, S)).init(state, MapState(T, U, S).process);
        }

        pub fn opt(self: Self) Parser(?T, OptState(T, S)) {
            const state = OptState(T, S){ .parser = self };
            return Parser(?T, OptState(T, S)).init(state, OptState(T, S).process);
        }

        pub fn not(self: Self) Parser(void, NotState(T, S)) {
            const state = NotState(T, S){ .parser = self };
            return Parser(void, NotState(T, S)).init(state, NotState(T, S).process);
        }

        pub fn recognize(self: Self) Parser(T, RecognizeState(T, S)) {
            const state = RecognizeState(T, S){ .parser = self };
            return Parser(T, RecognizeState(T, S)).init(state, RecognizeState(T, S).process);
        }
    };
}

pub fn ParseError(comptime K: type) type {
    return struct { cursor: usize, len: usize, input: []const u8, kind: ParseErrorKind(K) };
}

pub fn ParseErrorKind(comptime N: type) type {
    return union(enum) {
        tag: []const u8,
        one_of: Expectation([]const u8, u8),
        char: ExpectationSimple(u8),

        not: Unexpectation(N),
    };
}

fn MapState(comptime T: type, comptime U: type, comptime S: type) type {
    return struct {
        map: *const fn (T) U,
        parser: Parser(T, S),

        const Self = @This();
        pub const NotValue = getNotValue(S);

        pub fn process(self: Self, context: *Context) Result(U, ParseError(NotValue)) {
            const result = self.parser.runWithContext(context);
            return switch (result) {
                .err => |err| .{ .err = err },
                .ok => |value| .{ .ok = self.map(value) },
            };
        }
    };
}

fn OptState(comptime T: type, comptime S: type) type {
    return struct {
        parser: Parser(T, S),

        const Self = @This();
        pub const NotValue = getNotValue(S);

        pub fn process(self: Self, context: *Context) Result(?T, ParseError(void)) {
            const result = self.parser.runWithContext(context);
            return switch (result) {
                .err => blk: {
                    context.uncommit();
                    break :blk .{ .ok = null };
                },
                .ok => |value| .{ .ok = value },
            };
        }
    };
}

fn NotState(comptime T: type, comptime S: type) type {
    return struct {
        parser: Parser(T, S),

        const Self = @This();
        pub const NotValue = T;

        pub fn process(self: Self, context: *Context) Result(void, ParseError(NotValue)) {
            const result = self.parser.runWithContext(context);

            return switch (result) {
                .err => blk: {
                    context.uncommit();
                    break :blk .ok;
                },//.{.not = value}
                .ok => |value| .{ .err = .{
                    .cursor = context.cursor,
                    .len = context.dirty_cursor - context.cursor,
                    .input = context.input,

                    .kind = .{ .not = value },
                } },
            };
        }
    };
}

fn RecognizeState(comptime T: type, comptime S: type) type {
    return struct {
        parser: Parser(T, S),

        const Self = @This();
        pub const NotValue = getNotValue(S);

        pub fn process(self: Self, context: *Context) Result(T, ParseError(NotValue)) {
            const result = self.parser.runWithContext(context);
            context.uncommit();
            return result;
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

test "change the result of the parsing" {
    const tag = @import("./bytes.zig").tag;

    const parser = tag("hello");

    const result, const context = parser.run("hello");
    try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "hello" }, result);
    try testing.expectEqual(context.dirty_cursor, context.cursor);
    try testing.expectEqual(5, context.cursor);

    const result2, const context2 = parser.map(Hello, call_map).run("hello");
    try testing.expectEqualDeep(Result(Hello, ParseError(void)){ .ok = Hello{} }, result2);
    try testing.expectEqual(context2.dirty_cursor, context2.cursor);
    try testing.expectEqual(5, context2.cursor);
}

test "optional parsing" {
    const tag = @import("./bytes.zig").tag;

    const parser = tag("hello").opt();

    const result, const context = parser.runWithoutCommit("hello");
    try testing.expectEqualDeep(Result(?[]const u8, ParseError(void)){ .ok = "hello" }, result);
    try testing.expect(context.dirty_cursor > context.cursor);
    try testing.expectEqual(context.dirty_cursor, 5);
    try testing.expectEqual(context.cursor, 0);

    const result2, const context2 = parser.runWithoutCommit("world");
    try testing.expectEqualDeep(Result(?[]const u8, ParseError(void)){ .ok = null }, result2);
    try testing.expectEqual(context2.dirty_cursor, context2.cursor);
    try testing.expectEqual(context.cursor, 0);
}

test "not parsing" {
    const tag = @import("./bytes.zig").tag;

    const parser = tag("hello").recognize();

    const result, const context = parser.runWithoutCommit("hello");
    try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "hello" }, result);
    try testing.expectEqual(context.dirty_cursor, context.cursor);
    try testing.expectEqual(context.dirty_cursor, 0);
}
