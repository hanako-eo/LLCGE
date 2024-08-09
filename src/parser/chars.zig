const std = @import("std");

const Context = @import("./context.zig");

const parser_zig = @import("./parser.zig");
const Parser = parser_zig.Parser;
const ParseError = parser_zig.ParseError;
const StringParser = parser_zig.StringParser;

const Result = @import("../utils/types.zig").Result;

const CharState = struct {
    char: u8,

    const Self = @This();

    pub fn process(self: *Self, context: *Context) Result(u8, ParseError) {
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

    pub fn process(self: *Self, context: *Context) Result(u8, ParseError) {
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

const testing = std.testing;

test "parsing char" {
    var parser = char('(');

    const result, const context = parser.run("(hello) world!");
    try testing.expectEqualDeep(Result(u8, ParseError){ .ok = '(' }, result);
    try testing.expectEqual(context.dirty_cursor, context.cursor);
}

test "parsing one of chars" {
    var parser = one_of(&.{ '(', ')' });

    const result, const context = parser.run("(hello) world!");
    try testing.expectEqualDeep(Result(u8, ParseError){ .ok = '(' }, result);
    try testing.expectEqual(context.dirty_cursor, context.cursor);

    const result2, const context2 = parser.run(")hello( world!");
    try testing.expectEqualDeep(Result(u8, ParseError){ .ok = ')' }, result2);
    try testing.expectEqual(context2.dirty_cursor, context2.cursor);
}
