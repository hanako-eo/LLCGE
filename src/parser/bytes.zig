const std = @import("std");

const Context = @import("./context.zig");

const parser_zig = @import("../parser.zig");
const Parser = parser_zig.Parser;
const StringParser = parser_zig.StringParser;

const error_zig = @import("./error.zig");
const ParseError = error_zig.ParseError;
const ParseErrorKind = error_zig.ParseErrorKind;

const getStructAttribute = @import("../utils/meta.zig").getStructAttribute;
const owned_ref_zig = @import("../utils/owned_ref.zig");
const OwnedRef = owned_ref_zig.OwnedRef;
const OwnedValue = owned_ref_zig.OwnedValue;

const Result = @import("../utils/types.zig").Result;

const TagState = struct {
    tag: []const u8,

    const Self = @This();
    pub const NotValue = void;

    pub fn process(self: Self, context: *Context) Result([]const u8, ParseError(void)) {
        if (!std.mem.startsWith(u8, context.input[context.dirty_cursor..], self.tag)) {
            const cursor_end = @min(context.input.len, context.dirty_cursor + self.tag.len);
            return .{ .err = .{
                .cursor = context.dirty_cursor,
                .len = self.tag.len,
                .input = context.input,

                .kind = .{ .tag = .{ .expected = self.tag, .actual = context.input[context.dirty_cursor..cursor_end] } },
            } };
        }

        context.dirty_cursor += self.tag.len;
        return .{ .ok = context.input[context.cursor..context.dirty_cursor] };
    }
};

pub fn tag(expected_tag: []const u8) StringParser(TagState) {
    const state = TagState{ .tag = expected_tag };
    return StringParser(TagState).init(state, TagState.process);
}

const TakeWhileState = struct {
    predicate: OwnedRef(fn (u8) bool),

    const Self = @This();
    pub const NotValue = void;

    fn testChar(self: Self, char: u8) bool {
        return switch (self.predicate) {
            .owned => |owned| owned(char),
            .borrowed => |borrowed| borrowed(char),
        };
    }

    pub fn process(self: Self, context: *Context) Result([]const u8, ParseError(void)) {
        while (context.dirty_cursor < context.input.len and self.testChar(context.input[context.dirty_cursor])) {
            context.dirty_cursor += 1;
        }

        if (context.dirty_cursor == context.cursor) {
            return .{ .err = .{
                .cursor = context.dirty_cursor,
                .len = 1,
                .input = context.input,

                .kind = .{ .predicate = context.input[context.dirty_cursor] },
            } };
        }

        return .{ .ok = context.input[context.cursor..context.dirty_cursor] };
    }
};

pub fn take_while(predicate: anytype) StringParser(TakeWhileState) {
    const PredicateParser = @TypeOf(predicate);
    const state = if (PredicateParser == fn (u8) bool or PredicateParser == *const fn (u8) bool)
        TakeWhileState{ .predicate = OwnedRef(fn (u8) bool).fromAny(predicate) }
    else cond: {
        if (!@hasDecl(PredicateParser, "canParseOneByteAtATime") and !PredicateParser.canParseOneByteAtATime())
            @compileError(std.fmt.comptimePrint("{s} is not a Parser or it can parse more then one byte", .{@typeName(PredicateParser)}));

        break :cond TakeWhileState{ .predicate = OwnedValue(struct {
            fn call(c: u8) bool {
                return predicate.call(c);
            }
        }.call) };
    };

    return StringParser(TakeWhileState).init(state, TakeWhileState.process);
}

pub fn take_until(predicate: anytype) StringParser(TakeWhileState) {
    const state = TakeWhileState{ .predicate = OwnedValue(struct {
        fn call(c: u8) bool {
            const PredicateParser = @TypeOf(predicate);
            return !(if (PredicateParser == fn (u8) bool or PredicateParser == *const fn (u8) bool)
                predicate(c)
            else
                predicate.call(c));
        }
    }.call) };

    return StringParser(TakeWhileState).init(state, TakeWhileState.process);
}

fn EscapeState(comptime P1: type, comptime P2: type) type {
    if (getStructAttribute(P1, "Value") != []const u8)
        @compileError(std.fmt.comptimePrint("{s} should return '[]const u8' not '{s}'", .{ @typeName(P1), @typeName(P1.Value) }));

    if (getStructAttribute(P2, "Value") != u8)
        @compileError(std.fmt.comptimePrint("{s} should return 'u8' not '{s}'", .{ @typeName(P2), @typeName(P2.Value) }));

    return struct {
        parser: P1,
        control_char: u8,
        escapable: P2,

        const Self = @This();
        pub const NotValue = void;

        fn processEscape(self: Self, context: *Context) ?Result(void, ParseError(void)) {
            if (context.dirty_cursor >= context.input.len or context.input[context.dirty_cursor] != self.control_char)
                return null;

            context.dirty_cursor += 1;
            if (context.dirty_cursor >= context.input.len)
                return .{ .err = .{ .cursor = context.dirty_cursor, .len = 0, .input = context.input, .kind = .finished } };

            return switch (self.escapable.runWithContext(context)) {
                .err => |err| .{ .err = err },
                .ok => .ok,
            };
        }

        pub fn process(self: Self, context: *Context) Result([]const u8, ParseError(void)) {
            var result: Result([]const u8, ParseError(void)) = self.parser.runWithContext(context);
            var escaped_result: ?Result(void, ParseError(void)) = self.processEscape(context);

            while (escaped_result != null and escaped_result.? != .err) {
                result = self.parser.runWithContext(context);
                escaped_result = self.processEscape(context);
            }

            if (result == .err)
                return .{ .err = result.err };

            if (escaped_result != null)
                return .{ .err = escaped_result.?.err };

            return .{ .ok = context.input[context.cursor..context.dirty_cursor] };
        }
    };
}

pub fn escaped(comptime parser: anytype, control_char: u8, comptime escapable: anytype) StringParser(EscapeState(@TypeOf(parser), @TypeOf(escapable))) {
    const P1 = @TypeOf(parser);
    const P2 = @TypeOf(escapable);

    const state = EscapeState(P1, P2){ .parser = parser, .control_char = control_char, .escapable = escapable };
    return StringParser(EscapeState(P1, P2)).init(state, EscapeState(P1, P2).process);
}

const testing = std.testing;

test "parsing tag" {
    const parser = tag("hello");

    const result, const context = parser.run("hello world!");
    try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "hello" }, result);
    try testing.expectEqual(context.dirty_cursor, context.cursor);
    try testing.expectEqual(context.dirty_cursor, 5);

    const result2, const context2 = parser.run("helllo world!");
    try testing.expectEqualDeep(ParseErrorKind(void){ .tag = .{ .expected = "hello", .actual = "helll" } }, result2.err.kind);
    try testing.expectEqual(context2.dirty_cursor, context2.cursor);
    try testing.expectEqual(context2.dirty_cursor, 0);

    const result3, const context3 = parser.run("hi!");
    try testing.expectEqualDeep(ParseErrorKind(void){ .tag = .{ .expected = "hello", .actual = "hi!" } }, result3.err.kind);
    try testing.expectEqual(context3.dirty_cursor, context3.cursor);
    try testing.expectEqual(context3.dirty_cursor, 0);
}

test "parsing while is a alpha" {
    const alpha = @import("./chars.zig").alpha;

    const parser = take_while(std.ascii.isAlphabetic);
    const parser2 = take_while(alpha);

    const result, _ = parser.run("hello");
    try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "hello" }, result);

    const result2, _ = parser2.run("hello");
    try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "hello" }, result2);
}

test "parsing until a space" {
    const whitespace = @import("./chars.zig").whitespace;

    const parser = take_until(&std.ascii.isWhitespace);
    const parser2 = take_until(whitespace);

    const result, _ = parser.run("hello world");
    try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "hello" }, result);

    const result2, _ = parser2.run("bonjour monde");
    try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "bonjour" }, result2);
}

test "parsing number and escape ' with \\" {
    const char = @import("./chars.zig").char;
    const digit = @import("./chars.zig").digit;

    const parser = escaped(take_while(digit), '\\', char('\''));

    const result, _ = parser.run("123");
    try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "123" }, result);

    const result2, _ = parser.run("123 ");
    try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "123" }, result2);

    const result3, _ = parser.run("123\\'");
    try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "123\\'" }, result3);

    const result4, _ = parser.run("123\\'456");
    try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "123\\'456" }, result4);

    const result5, _ = parser.run("\\'456");
    try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "\\'456" }, result5);

    const result6, _ = parser.run("\\'123\\'456");
    try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "\\'123\\'456" }, result6);

    const result7, _ = parser.run("123\\");
    try testing.expectEqualDeep(.finished, result7.err.kind);

    const result8, _ = parser.run("123\\?");
    try testing.expectEqualDeep(ParseErrorKind(void){ .char = .{ .expected = '\'', .actual = '?' } }, result8.err.kind);
}
