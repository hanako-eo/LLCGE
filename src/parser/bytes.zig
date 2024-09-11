const std = @import("std");
const Allocator = std.mem.Allocator;

const Context = @import("./context.zig");

const parser_zig = @import("../parser.zig");
const Parser = parser_zig.Parser;
const StringParser = parser_zig.StringParser;

const error_zig = @import("./error.zig");
const ParseError = error_zig.ParseError;
const ParseErrorKind = error_zig.ParseErrorKind;

const get_struct_attribute = @import("../utils/meta.zig").get_struct_attribute;
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

    fn test_char(self: Self, char: u8) bool {
        return switch (self.predicate) {
            .owned => |owned| owned(char),
            .borrowed => |borrowed| borrowed(char),
        };
    }

    pub fn process(self: Self, context: *Context) Result([]const u8, ParseError(void)) {
        while (context.dirty_cursor < context.input.len and self.test_char(context.input[context.dirty_cursor])) {
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
        TakeWhileState{ .predicate = OwnedRef(fn (u8) bool).from_any(predicate) }
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
    const P1Value = get_struct_attribute(P1, "Value");

    return struct {
        parser: P1,
        control_char: u8,
        escapable: P2,

        const Self = @This();
        pub const NotValue = void;

        fn process_escape(self: Self, context: *Context) ?Result(void, ParseError(void)) {
            if (context.dirty_cursor >= context.input.len or context.input[context.dirty_cursor] != self.control_char)
                return null;

            context.dirty_cursor += 1;
            context.commit();
            if (context.dirty_cursor >= context.input.len)
                return .{ .err = .{ .cursor = context.dirty_cursor, .len = 0, .input = context.input, .kind = .finished } };

            return switch (self.escapable.run_with_context(context)) {
                .err => |err| .{ .err = err },
                .ok => blk: {
                    context.commit();
                    break :blk .ok;
                },
            };
        }

        fn process_parser(self: Self, context: *Context) ?Result(P1Value, ParseError(void)) {
            if (context.dirty_cursor >= context.input.len)
                return null;

            const result = self.parser.run_with_context(context);
            if (result == .ok)
                context.commit();

            return result;
        }

        pub fn process(self: Self, context: *Context) Result([]const u8, ParseError(void)) {
            const start = context.dirty_cursor;
            var result = self.process_parser(context);
            var escaped_result = self.process_escape(context);

            while (escaped_result != null and escaped_result.? != .err) {
                result = self.process_parser(context);
                escaped_result = self.process_escape(context);
            }

            if (result != null and result.? == .err) {
                context.uncommit();
                return .{ .err = result.?.err };
            }

            if (escaped_result != null) {
                context.uncommit();
                return .{ .err = escaped_result.?.err };
            }

            return .{ .ok = context.input[start..context.dirty_cursor] };
        }
    };
}

pub fn escaped(comptime parser: anytype, control_char: u8, comptime escapable: anytype) StringParser(EscapeState(@TypeOf(parser), @TypeOf(escapable))) {
    const P1 = @TypeOf(parser);
    const P2 = @TypeOf(escapable);

    const state = EscapeState(P1, P2){ .parser = parser, .control_char = control_char, .escapable = escapable };
    return StringParser(EscapeState(P1, P2)).init(state, EscapeState(P1, P2).process);
}

fn get_T_or_array_child_T(comptime T: type) struct { bool, type } {
    const info = @typeInfo(T);
    const child_type = switch (info) {
        .Array => |array| array.child,
        .Pointer => |ptr| ptr.child,
        else => T,
    };
    const is_array = switch (info) {
        .Array, .Pointer => true,
        else => false,
    };

    return .{ is_array, child_type };
}

fn get_T_or_array_child_T_of_value(comptime T: type) type {
    return get_T_or_array_child_T(get_struct_attribute(T, "Value")).@"1";
}

fn EscapeAndTransformState(comptime P1: type, comptime P2: type) type {
    const P1Value = get_struct_attribute(P1, "Value");
    const P2Value = get_struct_attribute(P2, "Value");

    const P1_value_is_array, const P1ValueCType = get_T_or_array_child_T(P1Value);
    const P2_value_is_array, const P2ValueCType = get_T_or_array_child_T(P2Value);

    if (P1ValueCType != P2ValueCType)
        @compileError(std.fmt.comptimePrint("'{s}' should be a '{1s}' or '[]const {1s}'", .{ @typeName(P2ValueCType), @typeName(P1ValueCType) }));

    return struct {
        parser: P1,
        control_char: u8,
        escapable: P2,

        allocator: Allocator,

        const Self = @This();
        pub const NotValue = void;

        fn init(allocator: Allocator, parser: P1, control_char: u8, escapable: P2) Self {
            return Self{ .parser = parser, .control_char = control_char, .escapable = escapable, .allocator = allocator };
        }

        fn process_escape(self: Self, buffer: *std.ArrayList(P1ValueCType), context: *Context) Allocator.Error!?Result(void, ParseError(void)) {
            if (context.dirty_cursor >= context.input.len or context.input[context.dirty_cursor] != self.control_char)
                return null;

            context.dirty_cursor += 1;
            context.commit();
            if (context.dirty_cursor >= context.input.len)
                return .{ .err = .{ .cursor = context.dirty_cursor, .len = 0, .input = context.input, .kind = .finished } };

            return switch (self.escapable.run_with_context(context)) {
                .err => |err| .{ .err = err },
                .ok => |value| blk: {
                    context.commit();
                    try if (P2_value_is_array)
                        buffer.appendSlice(value)
                    else
                        buffer.append(value);

                    break :blk .ok;
                },
            };
        }

        fn process_parser(self: Self, buffer: *std.ArrayList(P1ValueCType), context: *Context) Allocator.Error!?Result(P1Value, ParseError(void)) {
            if (context.dirty_cursor >= context.input.len)
                return null;

            const result = self.parser.run_with_context(context);
            if (result == .ok) {
                context.commit();
                try if (P1_value_is_array)
                    buffer.appendSlice(result.ok)
                else
                    buffer.append(result.ok);
            }

            return result;
        }

        pub fn process(self: Self, context: *Context) Result(std.ArrayList(P1ValueCType), ParseError(void)) {
            var buffer = std.ArrayList(P1ValueCType).init(self.allocator);

            var result = self.process_parser(&buffer, context) catch |err| return .{ .err = gen_alloc_error(&buffer, context, err) };
            var escaped_result = self.process_escape(&buffer, context) catch |err| return .{ .err = gen_alloc_error(&buffer, context, err) };

            while (escaped_result != null and escaped_result.? != .err) {
                result = self.process_parser(&buffer, context) catch |err| return .{ .err = gen_alloc_error(&buffer, context, err) };
                escaped_result = self.process_escape(&buffer, context) catch |err| return .{ .err = gen_alloc_error(&buffer, context, err) };
            }

            if (result != null and result.? == .err) {
                context.uncommit();
                buffer.deinit();
                return .{ .err = result.?.err };
            }

            if (escaped_result != null) {
                context.uncommit();
                buffer.deinit();
                return .{ .err = escaped_result.?.err };
            }

            return .{ .ok = buffer };
        }

        fn gen_alloc_error(buffer: *std.ArrayList(P1ValueCType), context: *Context, err: Allocator.Error) ParseError(void) {
            context.uncommit();
            buffer.deinit();
            return .{
                .cursor = 0,
                .len = 0,
                .input = context.input,

                .kind = .{ .allocation_error = err },
            };
        }
    };
}

pub fn escaped_and_transform(
    allocator: Allocator,
    comptime parser: anytype,
    control_char: u8,
    comptime escapable: anytype,
) Parser(std.ArrayList(get_T_or_array_child_T_of_value(@TypeOf(parser))), EscapeAndTransformState(@TypeOf(parser), @TypeOf(escapable))) {
    const P1 = @TypeOf(parser);
    const P1Child = get_T_or_array_child_T_of_value(P1);
    const P2 = @TypeOf(escapable);

    const state = EscapeAndTransformState(P1, P2).init(allocator, parser, control_char, escapable);
    return Parser(std.ArrayList(P1Child), EscapeAndTransformState(P1, P2)).init(state, EscapeAndTransformState(P1, P2).process);
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

test "parsing until is a num" {
    const digit = @import("./chars.zig").digit;

    const parser = take_until(std.ascii.isDigit);
    const parser2 = take_until(digit);

    const result, const context = parser.run("hello0world");
    try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "hello" }, result);
    try testing.expectEqualStrings("0world", context.get_dirty_residual());

    const result2, const context2 = parser2.run("hello0world");
    try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "hello" }, result2);
    try testing.expectEqualStrings("0world", context2.get_dirty_residual());
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

test "parsing string content, escape \\, \\n and \\t and get the result" {
    const char = @import("./chars.zig").char;
    const choice = @import("./branch.zig").choice;

    const parser = escaped_and_transform(testing.allocator, take_until(char('\\')), '\\', choice(.{ char('\\'), char('n').value(u8, '\n'), char('t').value(u8, '\t') }));

    const result, _ = parser.run("test1");
    defer result.ok.deinit();
    try testing.expectEqualDeep("test1", result.ok.items);

    const result2, _ = parser.run("test\\t");
    defer result2.ok.deinit();
    try testing.expectEqualDeep("test\t", result2.ok.items);

    const result3, _ = parser.run("\\ntest");
    defer result3.ok.deinit();
    try testing.expectEqualDeep("\ntest", result3.ok.items);

    const result4, _ = parser.run("test\\\\");
    defer result4.ok.deinit();
    try testing.expectEqualDeep("test\\", result4.ok.items);

    const result5, _ = parser.run("123\\?");
    try testing.expectEqualDeep(ParseErrorKind(void){ .char = .{ .expected = 't', .actual = '?' } }, result5.err.kind);
}
