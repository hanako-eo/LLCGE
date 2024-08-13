const std = @import("std");

const Context = @import("./context.zig");

const parser_zig = @import("../parser.zig");
const Parser = parser_zig.Parser;
const StringParser = parser_zig.StringParser;

const ParseError = @import("./error.zig").ParseError;

const Result = @import("../utils/types.zig").Result;

const CharState = struct {
    char: u8,

    const Self = @This();
    pub const NotValue = void;

    pub fn call(self: Self, c: u8) bool {
        return self.char == c;
    }

    pub fn process(self: Self, context: *Context) Result(u8, ParseError(NotValue)) {
        const current_char = context.input[context.dirty_cursor];
        if (current_char != self.char) {
            return .{ .err = .{
                .cursor = context.dirty_cursor,
                .len = 1,
                .input = context.input,

                .kind = .{ .char = .{ .expected = self.char, .actual = current_char } },
            } };
        }

        context.dirty_cursor += 1;

        return .{ .ok = self.char };
    }
};

pub fn char(expected_char: u8) Parser(u8, CharState) {
    const parser = CharState{ .char = expected_char };
    return Parser(u8, CharState).init(parser, CharState.process);
}

const OneOfState = struct {
    chars: []const u8,

    const Self = @This();
    pub const NotValue = void;

    pub fn call(self: Self, c: u8) bool {
        for (self.chars) |one_of_c| {
            if (one_of_c == c)
                return true;
        }
        return false;
    }

    pub fn process(self: Self, context: *Context) Result(u8, ParseError(NotValue)) {
        const current_char = context.input[context.dirty_cursor];
        for (self.chars) |one_of_char| {
            if (current_char == one_of_char) {
                context.dirty_cursor += 1;

                return .{ .ok = current_char };
            }
        }

        return .{ .err = .{
            .cursor = context.dirty_cursor,
            .len = 1,
            .input = context.input,

            .kind = .{ .one_of = .{ .expected = self.chars, .actual = current_char } },
        } };
    }
};

pub fn one_of(expected_chars: []const u8) Parser(u8, OneOfState) {
    const parser = OneOfState{ .chars = expected_chars };
    return Parser(u8, OneOfState).init(parser, OneOfState.process);
}

const CharPredicateState = struct {
    predicate: *const fn (u8) bool,

    const Self = @This();
    pub const NotValue = void;

    pub fn call(self: Self, c: u8) bool {
        return self.predicate(c);
    }

    pub fn process(self: Self, context: *Context) Result(u8, ParseError(NotValue)) {
        const current_char = context.input[context.dirty_cursor];
        if (self.predicate(current_char)) {
            context.dirty_cursor += 1;

            return .{ .ok = current_char };
        }

        return .{ .err = .{
            .cursor = context.dirty_cursor,
            .len = 1,
            .input = context.input,

            .kind = .{ .predicate = current_char },
        } };
    }
};

pub fn char_predicate(predicate: fn (u8) bool) Parser(u8, CharPredicateState) {
    const parser = CharPredicateState{ .predicate = predicate };
    return Parser(u8, CharPredicateState).init(parser, CharPredicateState.process);
}

pub const alpha = char_predicate(std.ascii.isAlphabetic);
pub const alphanum = char_predicate(std.ascii.isAlphanumeric);
pub const digit = char_predicate(std.ascii.isDigit);
pub const whitespace = char_predicate(std.ascii.isWhitespace);
pub const hex = char_predicate(std.ascii.isHex);

const testing = std.testing;

test "parsing char" {
    const parser = char('(');

    const result, const context = parser.run("(hello) world!");
    try testing.expectEqualDeep(Result(u8, ParseError(void)){ .ok = '(' }, result);
    try testing.expectEqual(context.dirty_cursor, context.cursor);
}

test "parsing one of chars" {
    const parser = one_of(&.{ '(', ')' });

    const result, const context = parser.run("(hello) world!");
    try testing.expectEqualDeep(Result(u8, ParseError(void)){ .ok = '(' }, result);
    try testing.expectEqual(context.dirty_cursor, context.cursor);

    const result2, const context2 = parser.run(")hello( world!");
    try testing.expectEqualDeep(Result(u8, ParseError(void)){ .ok = ')' }, result2);
    try testing.expectEqual(context2.dirty_cursor, context2.cursor);
}

test "parsing alpha" {
    const parser = one_of(&.{ '(', ')' });

    const result, const context = parser.run("(hello) world!");
    try testing.expectEqualDeep(Result(u8, ParseError(void)){ .ok = '(' }, result);
    try testing.expectEqual(context.dirty_cursor, context.cursor);

    const result2, const context2 = parser.run(")hello( world!");
    try testing.expectEqualDeep(Result(u8, ParseError(void)){ .ok = ')' }, result2);
    try testing.expectEqual(context2.dirty_cursor, context2.cursor);
}
