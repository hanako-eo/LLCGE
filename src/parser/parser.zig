const std = @import("std");

const Context = @import("./context.zig");

const error_zig = @import("./error.zig");
const ParseError = error_zig.ParseError;
const ParseErrorKind = error_zig.ParseErrorKind;

const types_zig = @import("../utils/types.zig");
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
        pub const Value = T;

        state: S,
        lambda: *const fn (S, *Context) Result(T, ParseError(NotValue)),

        const Self = @This();

        pub fn init(state: S, lambda: fn (S, *Context) Result(T, ParseError(NotValue))) Self {
            return Self{ .lambda = lambda, .state = state };
        }

        pub inline fn runWithContext(self: Self, context: *Context) Result(T, ParseError(NotValue)) {
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
        pub inline fn forgot(self: Self) Parser(void, MapState(T, void, S)) {
            return self.map(void, struct {
                fn call(_: T) void {}
            }.call);
        }

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

        pub fn recognize(self: Self) Parser(void, UnconsumerState(false, T, S)) {
            const state = UnconsumerState(false, T, S){ .parser = self };
            return Parser(void, UnconsumerState(false, T, S)).init(state, UnconsumerState(false, T, S).process);
        }

        pub fn peek(self: Self) Parser(T, UnconsumerState(true, T, S)) {
            const state = UnconsumerState(true, T, S){ .parser = self };
            return Parser(T, UnconsumerState(true, T, S)).init(state, UnconsumerState(true, T, S).process);
        }

        pub fn satisfy_fn(self: Self, lambda: *const fn (*const T) bool, message_fn: *const fn (*const T) []const u8) Parser(T, SatisfyFnState(T, S)) {
            const state = SatisfyFnState(T, S){ .parser = self, .satisfy = lambda, .message_fn = message_fn };
            return Parser(T, SatisfyFnState(T, S)).init(state, SatisfyFnState(T, S).process);
        }

        pub inline fn satisfy(self: Self, lambda: *const fn (*const T) bool, comptime message: []const u8) Parser(T, SatisfyFnState(T, S)) {
            return self.satisfy_fn(lambda, struct {
                fn call(_: *const T) []const u8 {
                    return message;
                }
            }.call);
        }

        pub fn finished(self: Self) Parser(T, FinishedState(T, S)) {
            const state = FinishedState(T, S){ .parser = self };
            return Parser(T, FinishedState(T, S)).init(state, FinishedState(T, S).process);
        }

        pub fn finishedZ(self: Self) Parser(T, FinishedState(T, S)) {
            const state = FinishedState(T, S){ .parser = self };
            return Parser(T, FinishedState(T, S)).init(state, FinishedState(T, S).processZ);
        }
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
                .err => .ok,
                .ok => |value| blk: {
                    context.uncommit();
                    break :blk .{ .err = .{
                        .cursor = context.cursor,
                        .len = context.dirty_cursor - context.cursor,
                        .input = context.input,

                        .kind = .{ .not = value },
                    } };
                },
            };
        }
    };
}

fn UnconsumerState(comptime peeking: bool, comptime T: type, comptime S: type) type {
    return struct {
        parser: Parser(T, S),

        const Self = @This();
        pub const NotValue = getNotValue(S);

        const ReturnValue = if (peeking) T else void;

        pub fn process(self: Self, context: *Context) Result(ReturnValue, ParseError(NotValue)) {
            const result = self.parser.runWithContext(context);
            context.uncommit();
            if (peeking) {
                return result;
            } else {
                return .ok;
            }
        }
    };
}

fn SatisfyFnState(comptime T: type, comptime S: type) type {
    return struct {
        satisfy: *const fn (*const T) bool,
        message_fn: *const fn (*const T) []const u8,
        parser: Parser(T, S),

        const Self = @This();
        pub const NotValue = getNotValue(S);

        pub fn process(self: Self, context: *Context) Result(T, ParseError(NotValue)) {
            const result = self.parser.runWithContext(context);
            return switch (result) {
                .err => |err| .{ .err = err },
                .ok => |value| if (!self.satisfy(&value)) .{ .err = .{
                    .cursor = context.cursor,
                    .len = context.dirty_cursor - context.cursor,
                    .input = context.input,

                    .kind = .{ .satisfy = self.message_fn(&value) },
                } } else .{ .ok = value },
            };
        }
    };
}

fn FinishedState(comptime T: type, comptime S: type) type {
    return struct {
        parser: Parser(T, S),

        const Self = @This();
        pub const NotValue = getNotValue(S);

        pub fn process(self: Self, context: *Context) Result(T, ParseError(NotValue)) {
            return self.processImpl(context, struct {
                fn call(ctx: *Context) bool {
                    return ctx.input.len <= ctx.dirty_cursor;
                }
            }.call);
        }

        pub fn processZ(self: Self, context: *Context) Result(T, ParseError(NotValue)) {
            return self.processImpl(context, struct {
                fn call(ctx: *Context) bool {
                    return ctx.input.len <= ctx.dirty_cursor or ctx.input[ctx.dirty_cursor] == 0;
                }
            }.call);
        }

        fn processImpl(self: Self, context: *Context, comptime predicate: fn (*Context) bool) Result(T, ParseError(NotValue)) {
            const result = self.parser.runWithContext(context);
            if (predicate(context))
                return result;

            return .{ .err = .{
                .cursor = context.cursor,
                .len = 0,
                .input = context.input,

                .kind = .not_finished,
            } };
        }
    };
}

const testing = std.testing;
const tag = @import("./bytes.zig").tag;

test "import parsing tests" {
    _ = @import("./branch.zig");
    _ = @import("./bytes.zig");
    _ = @import("./chars.zig");
}

const Hello = struct {};
fn call_map(_: []const u8) Hello {
    return Hello{};
}

test "change the result of the parsing" {
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
    const parser = tag("hello").not();

    const result, const context = parser.runWithoutCommit("hello");
    try testing.expectEqualDeep(ParseErrorKind([]const u8){ .not = "hello" }, result.err.kind);
    try testing.expectEqual(context.dirty_cursor, context.cursor);
    try testing.expectEqual(context.dirty_cursor, 0);

    const result2, const context2 = parser.runWithoutCommit("world");
    try testing.expectEqualDeep(.ok, result2);
    try testing.expectEqual(context2.dirty_cursor, context2.cursor);
    try testing.expectEqual(context2.dirty_cursor, 0);
}

test "recognize without peeking parsing" {
    const parser = tag("hello").recognize();

    const result, const context = parser.runWithoutCommit("hello");
    try testing.expectEqualDeep(.ok, result);
    try testing.expectEqual(context.dirty_cursor, context.cursor);
    try testing.expectEqual(context.dirty_cursor, 0);
}

test "recognize with peeking parsing" {
    const parser = tag("hello").peek();

    const result, const context = parser.runWithoutCommit("hello");
    try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "hello" }, result);
    try testing.expectEqual(context.dirty_cursor, context.cursor);
    try testing.expectEqual(context.dirty_cursor, 0);
}

fn safisfy_true(_: *const []const u8) bool {
    return true;
}

fn safisfy_false(_: *const []const u8) bool {
    return false;
}

test "parsing with satisfaction of condition" {
    const parser = tag("hello");

    const result, _ = parser.satisfy(safisfy_true, "unexpected value").runWithoutCommit("hello");
    try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "hello" }, result);

    const result2, _ = parser.satisfy(safisfy_false, "expected value").runWithoutCommit("hello");
    try testing.expectEqualDeep(ParseErrorKind(void){ .satisfy = "expected value" }, result2.err.kind);
}

test "check if the parser parse all" {
    const parser = tag("hello").finished();
    const parser2 = tag("hello").finishedZ();

    const result, _ = parser.runWithoutCommit("hello");
    try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "hello" }, result);

    const result2, _ = parser.runWithoutCommit("hello!");
    try testing.expectEqualDeep(.not_finished, result2.err.kind);

    const result3, _ = parser2.runWithoutCommit("hello");
    try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "hello" }, result3);

    const result4, _ = parser2.runWithoutCommit("hello!");
    try testing.expectEqualDeep(.not_finished, result4.err.kind);
}
