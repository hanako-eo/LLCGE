const std = @import("std");

const parser_zig = @import("./lib.zig");
const Parser = parser_zig.Parser;
const ParseResult = parser_zig.ParseResult;

const error_zig = @import("./error.zig");
const ParseErrorKind = error_zig.ParseErrorKind;

const meta = @import("./utils/meta.zig");

const Result = @import("./utils/types.zig").Result;

const Pair = @import("utils").Pair;

/// Parse both given parser and ignore the result of the first to only get the
/// parsing result of the second.
pub fn preceded(comptime first: anytype, comptime second: anytype) Parser(meta.ParserLikeResult(second)) {
    if (!meta.is_parser_like(first))
        @compileError("the first input must be a parser (or look like a parser).");
    const T = meta.ParserLikeResult(second);

    return Parser(T).init(struct {
        pub fn call(input: []const u8) ParseResult(T, []const u8) {
            const first_result = first.run(input);
            if (first_result == .err) {
                return ParseResult(T, []const u8).Err(first_result.err);
            }

            return second.run(first_result.ok.second);
        }
    });
}

/// Parse both given parser and ignore the result of the second to only get the
/// parsing result of the first.
pub fn terminated(comptime first: anytype, comptime second: anytype) Parser(meta.ParserLikeResult(first)) {
    const T = meta.ParserLikeResult(first);
    if (!meta.is_parser_like(second))
        @compileError("the first input must be a parser (or look like a parser).");

    return Parser(T).init(struct {
        pub fn call(input: []const u8) ParseResult(T, []const u8) {
            const first_result = first.run(input);
            if (first_result == .err) {
                return first_result;
            }

            return switch (second.run(first_result.ok.second)) {
                .err => |err| ParseResult(T, []const u8).Err(err),
                .ok => |second_result| ParseResult(T, []const u8).Ok(Pair(T, []const u8).init(first_result.ok.first, second_result.second))
            };
        }
    });
}

/// Parse all three given parser and ignore the result of the first and third
/// to only get the parsing result of the second. 
pub inline fn delimited(comptime first: anytype, comptime second: anytype, comptime third: anytype) Parser(meta.ParserLikeResult(second)) {
    return preceded(first, terminated(second, third));
}

const testing = std.testing;
const tag = @import("./bytes.zig").tag;
const char = @import("./chars.zig").char;
const whitespace = @import("./chars.zig").whitespace;

test "parsing def with abc before" {
    const parser = preceded(tag("abc"), tag("def"));

    const result = parser.run("abcdef");
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("def", "")), result);
}

test "parsing abc with def after" {
    const parser = terminated(tag("abc"), tag("def"));

    const result = parser.run("abcdef");
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("abc", "")), result);
}

test "parsing abc with \" around" {
    const parser = delimited(char('"'), tag("abc"), char('"'));

    const result = parser.run("\"abc\"");
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("abc", "")), result);
}
