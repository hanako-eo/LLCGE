const std = @import("std");

pub const branch = @import("./parser/branch.zig");
pub const bytes = @import("./parser/bytes.zig");
pub const chars = @import("./parser/chars.zig");
pub const Context = @import("./parser/context.zig");
pub const errors = @import("./parser/error.zig");

const ParseError = errors.ParseError;
const ParseErrorKind = errors.ParseErrorKind;

const Result = @import("./utils/types.zig").Result;

const get_struct_attribute = @import("./utils/meta.zig").get_struct_attribute;

const owned_ref_zig = @import("./utils/owned_ref.zig");
const OwnedRef = owned_ref_zig.OwnedRef;
const OwnedValue = owned_ref_zig.OwnedValue;

pub fn StringParser(comptime S: type) type {
    return Parser([]const u8, S);
}
pub fn Parser(comptime T: type, comptime S: type) type {
    const NotValue = get_struct_attribute(S, "NotValue");

    if (T == u8 and !@hasDecl(S, "call"))
        @compileError(std.fmt.comptimePrint("{0s} need to implement 'fn call({0s}, u8) bool' because it only handles one byte at a time", .{@typeName(S)}));

    return struct {
        pub const Value = T;

        state: S,
        lambda: OwnedRef(fn (S, *Context) Result(T, ParseError(NotValue))),

        const Self = @This();

        pub fn can_parse_one_byte_at_a_time() bool {
            return T == u8;
        }

        pub fn init(state: S, comptime lambda: anytype) Self {
            return Self{ .lambda = OwnedRef(fn (S, *Context) Result(T, ParseError(NotValue))).from_any(lambda), .state = state };
        }

        pub inline fn run_with_context_without_commit(self: Self, context: *Context) Result(T, ParseError(NotValue)) {
            return switch (self.lambda) {
                .owned => |owned| owned(self.state, context),
                .borrowed => |borrowed| borrowed(self.state, context),
            };
        }

        pub fn run_with_context(self: Self, context: *Context) Result(T, ParseError(NotValue)) {
            const result = self.run_with_context_without_commit(context);
            context.commit();
            return result;
        }

        pub fn run_without_commit(self: Self, input: []const u8) struct { Result(T, ParseError(NotValue)), Context } {
            var context = Context.init(input);

            return .{ self.run_with_context_without_commit(&context), context };
        }

        pub fn run(self: Self, input: []const u8) struct { Result(T, ParseError(NotValue)), Context } {
            const result, var context = self.run_without_commit(input);
            context.commit();
            return .{ result, context };
        }

        pub fn call(self: Self, c: u8) bool {
            return self.state.call(c);
        }

        // modifiers
        pub inline fn forgot(self: Self) Parser(void, MapState(T, void, S)) {
            return self.value(void, void{});
        }

        pub inline fn into_array(self: Self) Parser([]const T, MapState(T, []const T, S)) {
            return self.map([]const T, struct {
                fn call(v: T) []const T {
                    return .{v};
                }
            }.call);
        }

        pub inline fn value(self: Self, comptime U: type, v: U) Parser(U, MapState(T, U, S)) {
            return self.map(U, struct {
                fn call(_: T) U {
                    return v;
                }
            }.call);
        }

        pub fn map(self: Self, comptime U: type, lambda: anytype) Parser(U, MapState(T, U, S)) {
            const state = MapState(T, U, S){ .map = OwnedRef(fn (T) U).from_any(lambda), .parser = self };
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

        pub fn satisfy_fn(self: Self, lambda: anytype, message_fn: anytype) Parser(T, SatisfyFnState(T, S)) {
            const state = SatisfyFnState(T, S){ .parser = self, .satisfy = OwnedRef(fn (*const T) bool).from_any(lambda), .message_fn = OwnedRef(fn (*const T) []const u8).from_any(message_fn) };
            return Parser(T, SatisfyFnState(T, S)).init(state, SatisfyFnState(T, S).process);
        }

        pub inline fn satisfy(self: Self, lambda: anytype, comptime message: []const u8) Parser(T, SatisfyFnState(T, S)) {
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

        pub fn finished_z(self: Self) Parser(T, FinishedState(T, S)) {
            const state = FinishedState(T, S){ .parser = self };
            return Parser(T, FinishedState(T, S)).init(state, FinishedState(T, S).process_z);
        }

        pub fn followed_by(self: Self, lambda: anytype) Parser(T, FollowedByState(T, S)) {
            const state = FollowedByState(T, S){ .lambda = OwnedRef(fn (u8) bool).from_any(lambda), .parser = self };
            return Parser(T, FollowedByState(T, S)).init(state, FollowedByState(T, S).process);
        }
    };
}

pub fn MapState(comptime T: type, comptime U: type, comptime S: type) type {
    return struct {
        map: OwnedRef(fn (T) U),
        parser: Parser(T, S),

        const Self = @This();
        pub const NotValue = get_struct_attribute(S, "NotValue");

        pub fn call(self: Self, c: u8) bool {
            return self.parser.call(c);
        }

        pub fn process(self: Self, context: *Context) Result(U, ParseError(NotValue)) {
            const result = self.parser.run_with_context_without_commit_without_commit(context);
            return switch (result) {
                .err => |err| .{ .err = err },
                .ok => |value| .{ .ok = switch (self.map) {
                    .owned => |owned| owned(value),
                    .borrowed => |borrowed| borrowed(value),
                } },
            };
        }
    };
}

pub fn OptState(comptime T: type, comptime S: type) type {
    return struct {
        parser: Parser(T, S),

        const Self = @This();
        pub const NotValue = get_struct_attribute(S, "NotValue");

        pub fn call(self: Self, c: u8) bool {
            return self.parser.call(c);
        }

        pub fn process(self: Self, context: *Context) Result(?T, ParseError(void)) {
            const result = self.parser.run_with_context_without_commit_without_commit(context);
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

pub fn NotState(comptime T: type, comptime S: type) type {
    return struct {
        parser: Parser(T, S),

        const Self = @This();
        pub const NotValue = T;

        pub fn process(self: Self, context: *Context) Result(void, ParseError(NotValue)) {
            const result = self.parser.run_with_context_without_commit(context);

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

pub fn UnconsumerState(comptime peeking: bool, comptime T: type, comptime S: type) type {
    return struct {
        parser: Parser(T, S),

        const Self = @This();
        pub const NotValue = get_struct_attribute(S, "NotValue");

        const ReturnValue = if (peeking) T else void;

        pub fn call(self: Self, c: u8) bool {
            return self.parser.call(c);
        }

        pub fn process(self: Self, context: *Context) Result(ReturnValue, ParseError(NotValue)) {
            const result = self.parser.run_with_context_without_commit(context);
            context.uncommit();
            if (peeking) {
                return result;
            } else {
                return .ok;
            }
        }
    };
}

pub fn SatisfyFnState(comptime T: type, comptime S: type) type {
    return struct {
        satisfy: OwnedRef(fn (*const T) bool),
        message_fn: OwnedRef(fn (*const T) []const u8),
        parser: Parser(T, S),

        const Self = @This();
        pub const NotValue = get_struct_attribute(S, "NotValue");

        pub fn call(self: Self, c: u8) bool {
            return self.parser.call(c);
        }

        fn @"test"(self: Self, value: *const T) bool {
            return switch (self.satisfy) {
                .owned => |owned| owned(value),
                .borrowed => |borrowed| borrowed(value),
            };
        }

        fn get_message(self: Self, value: *const T) []const u8 {
            return switch (self.message_fn) {
                .owned => |owned| owned(value),
                .borrowed => |borrowed| borrowed(value),
            };
        }

        pub fn process(self: Self, context: *Context) Result(T, ParseError(NotValue)) {
            const result = self.parser.run_with_context_without_commit(context);
            return switch (result) {
                .err => |err| .{ .err = err },
                .ok => |value| if (!self.@"test"(&value)) .{ .err = .{
                    .cursor = context.cursor,
                    .len = context.dirty_cursor - context.cursor,
                    .input = context.input,

                    .kind = .{ .satisfy = self.get_message(&value) },
                } } else .{ .ok = value },
            };
        }
    };
}

pub fn FinishedState(comptime T: type, comptime S: type) type {
    return struct {
        parser: Parser(T, S),

        const Self = @This();
        pub const NotValue = get_struct_attribute(S, "NotValue");

        pub fn call(self: Self, c: u8) bool {
            return self.parser.call(c);
        }

        pub fn process(self: Self, context: *Context) Result(T, ParseError(NotValue)) {
            return self.process_impl(context, struct {
                fn call(ctx: *Context) bool {
                    return ctx.input.len <= ctx.dirty_cursor;
                }
            }.call);
        }

        pub fn process_z(self: Self, context: *Context) Result(T, ParseError(NotValue)) {
            return self.process_impl(context, struct {
                fn call(ctx: *Context) bool {
                    return ctx.input.len <= ctx.dirty_cursor or ctx.input[ctx.dirty_cursor] == 0;
                }
            }.call);
        }

        fn process_impl(self: Self, context: *Context, comptime predicate: fn (*Context) bool) Result(T, ParseError(NotValue)) {
            const result = self.parser.run_with_context_without_commit(context);
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

pub fn FollowedByState(comptime T: type, comptime S: type) type {
    return struct {
        lambda: OwnedRef(fn (u8) bool),
        parser: Parser(T, S),

        const Self = @This();
        pub const NotValue = get_struct_attribute(S, "NotValue");

        pub fn call(self: Self, c: u8) bool {
            return self.parser.call(c);
        }

        fn process(self: Self, context: *Context) Result(T, ParseError(NotValue)) {
            const result = self.parser.run_with_context_without_commit(context);
            if (result == .err or context.input.len <= context.dirty_cursor)
                return result;

            const correctly_followed = switch (self.lambda) {
                .owned => |owned| owned(context.input[context.dirty_cursor]),
                .borrowed => |borrowed| borrowed(context.input[context.dirty_cursor]),
            };

            if (!correctly_followed)
                return .{ .err = .{
                    .cursor = context.dirty_cursor,
                    .len = 1,
                    .input = context.input,

                    .kind = .{ .unexpected = context.input[context.dirty_cursor] },
                } };

            return result;
        }
    };
}

test {
    _ = branch;
    _ = bytes;
    _ = chars;
}

const testing = std.testing;
const tag = bytes.tag;

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

    const result, const context = parser.run_without_commit("hello");
    try testing.expectEqualDeep(Result(?[]const u8, ParseError(void)){ .ok = "hello" }, result);
    try testing.expect(context.dirty_cursor > context.cursor);
    try testing.expectEqual(context.dirty_cursor, 5);
    try testing.expectEqual(context.cursor, 0);

    const result2, const context2 = parser.run_without_commit("world");
    try testing.expectEqualDeep(Result(?[]const u8, ParseError(void)){ .ok = null }, result2);
    try testing.expectEqual(context2.dirty_cursor, context2.cursor);
    try testing.expectEqual(context.cursor, 0);
}

test "not parsing" {
    const parser = tag("hello").not();

    const result, const context = parser.run_without_commit("hello");
    try testing.expectEqualDeep(ParseErrorKind([]const u8){ .not = "hello" }, result.err.kind);
    try testing.expectEqual(context.dirty_cursor, context.cursor);
    try testing.expectEqual(context.dirty_cursor, 0);

    const result2, const context2 = parser.run_without_commit("world");
    try testing.expectEqualDeep(.ok, result2);
    try testing.expectEqual(context2.dirty_cursor, context2.cursor);
    try testing.expectEqual(context2.dirty_cursor, 0);
}

test "recognize without peeking parsing" {
    const parser = tag("hello").recognize();

    const result, const context = parser.run_without_commit("hello");
    try testing.expectEqualDeep(.ok, result);
    try testing.expectEqual(context.dirty_cursor, context.cursor);
    try testing.expectEqual(context.dirty_cursor, 0);
}

test "recognize with peeking parsing" {
    const parser = tag("hello").peek();

    const result, const context = parser.run_without_commit("hello");
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

    const result, _ = parser.satisfy(safisfy_false, "unexpected value").run_without_commit("hello");
    try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "hello" }, result);

    const result2, _ = parser.satisfy(safisfy_false, "expected value").run_without_commit("hello");
    try testing.expectEqualDeep(ParseErrorKind(void){ .satisfy = "expected value" }, result2.err.kind);
}

test "check if the parser parse all" {
    const parser = tag("hello").finished();
    const parser2 = tag("hello").finished_z();

    const result, _ = parser.run_without_commit("hello");
    try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "hello" }, result);

    const result2, _ = parser.run_without_commit("hello!");
    try testing.expectEqualDeep(.not_finished, result2.err.kind);

    const result3, _ = parser2.run_without_commit("hello");
    try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "hello" }, result3);

    const result4, _ = parser2.run_without_commit("hello!");
    try testing.expectEqualDeep(.not_finished, result4.err.kind);
}

test "check if 'hello' is followed by a whitespace char" {
    const parser = tag("hello").followed_by(std.ascii.isWhitespace);

    const result, const context = parser.run("hello");
    try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "hello" }, result);
    try testing.expectEqual(context.dirty_cursor, context.cursor);
    try testing.expectEqual(5, context.cursor);

    const result2, const context2 = parser.run("hello world");
    try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "hello" }, result2);
    try testing.expectEqual(context2.dirty_cursor, context2.cursor);
    try testing.expectEqual(5, context2.cursor);

    const result3, _ = parser.run("helloo");
    try testing.expectEqualDeep(ParseErrorKind(void){ .unexpected = ' ' }, result3.err.kind);
}
