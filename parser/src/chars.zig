const std = @import("std");

const parser_zig = @import("./lib.zig");
const Parser = parser_zig.Parser;
const ParseResult = parser_zig.ParseResult;

const error_zig = @import("./error.zig");
const ParseErrorKind = error_zig.ParseErrorKind;

const meta = @import("./utils/meta.zig");

const Result = @import("./utils/types.zig").Result;

const Pair = @import("utils").Pair;

pub fn char(comptime expected_char: u8) Parser(u8) {
    return Parser(u8).init(struct {
        pub fn call(input: []const u8) ParseResult(u8, []const u8) {
            const first_char = input[0];
            if (first_char != expected_char) {
                return ParseResult(u8, []const u8).Err(.{
                    .input = input,
                    .kind = .{ .char = .{ .expected = expected_char, .actual = first_char } },
                });
            }

            return ParseResult(u8, []const u8).Ok(Pair(u8, []const u8).init(first_char, input[1..]));
        }
    });
}

pub fn one_of(comptime expected_chars: []const u8) Parser(u8) {
    return char_predicate(struct {
        pub fn call(current_char: u8) bool {
            for (expected_chars) |one_of_char| {
                if (current_char == one_of_char) {
                    return true;
                }
            }

            return false;
        }
    });
}

pub fn char_predicate(comptime raw_predicate: anytype) Parser(u8) {
    const predicate = comptime meta.callable(fn(u8) bool, raw_predicate) orelse @compileError("The input predicate need to be callable.");

    return Parser(u8).init(struct {
        pub fn call(input: []const u8) ParseResult(u8, []const u8) {
            const first_char = input[0];
            if (!predicate(first_char)) {
                return ParseResult(u8, []const u8).Err(.{
                    .input = input,
                    .kind = .{ .unexpected = first_char },
                });
            }

            return ParseResult(u8, []const u8).Ok(Pair(u8, []const u8).init(first_char, input[1..]));
        }
    });
}

pub const any_char = char_predicate(struct {
    fn call(_: u8) bool {
        return true;
    }
});
pub const alpha = char_predicate(std.ascii.isAlphabetic);
pub const alphanum = char_predicate(std.ascii.isAlphanumeric);
pub const digit = char_predicate(std.ascii.isDigit);
pub const whitespace = char_predicate(std.ascii.isWhitespace);
pub const hex = char_predicate(std.ascii.isHex);

const testing = std.testing;

test "parsing char" {
    const parser = char('(');

    const result = parser.run("(hello) world!");
    try testing.expectEqualDeep(ParseResult(u8, []const u8).Ok(Pair(u8, []const u8).init('(', "hello) world!")), result);
}

test "parsing one of chars" {
    const parser = one_of(&.{ '(', ')' });

    const result = parser.run("(hello) world!");
    try testing.expectEqualDeep(ParseResult(u8, []const u8).Ok(Pair(u8, []const u8).init('(', "hello) world!")), result);

    const result2 = parser.run(")hello( world!");
    try testing.expectEqualDeep(ParseResult(u8, []const u8).Ok(Pair(u8, []const u8).init(')', "hello( world!")), result2);
}

test "parsing alpha" {
    const parser = alpha;

    const result = parser.run("hello world!");
    try testing.expectEqualDeep(ParseResult(u8, []const u8).Ok(Pair(u8, []const u8).init('h', "ello world!")), result);

    const result2 = parser.run(")hello( world!");
    try testing.expectEqualDeep(ParseErrorKind{ .unexpected = ')' }, result2.err.kind);
}
