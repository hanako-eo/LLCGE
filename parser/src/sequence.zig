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
        pub fn call(input: []const u8, allocator: std.mem.Allocator) ParseResult(T, []const u8) {
            const first_result = first.run(input, allocator);
            if (first_result == .err) {
                return ParseResult(T, []const u8).Err(first_result.err);
            }

            return second.run(first_result.ok.second, allocator);
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
        pub fn call(input: []const u8, allocator: std.mem.Allocator) ParseResult(T, []const u8) {
            const first_result = first.run(input, allocator);
            if (first_result == .err) {
                return first_result;
            }

            return switch (second.run(first_result.ok.second, allocator)) {
                .err => |err| ParseResult(T, []const u8).Err(err),
                .ok => |second_result| ParseResult(T, []const u8).Ok(Pair(T, []const u8).init(first_result.ok.first, second_result.second)),
            };
        }
    });
}

/// Parse all three given parser and ignore the result of the first and third
/// to only get the parsing result of the second.
pub inline fn delimited(comptime first: anytype, comptime second: anytype, comptime third: anytype) Parser(meta.ParserLikeResult(second)) {
    return preceded(first, terminated(second, third));
}

pub fn separated_pair(comptime first: anytype, comptime separator: anytype, comptime second: anytype) Parser(meta.StructFromParsers(.{ first, second })) {
    const T = meta.StructFromParsers(.{ first, second });

    return parser_zig.branch.chain(.{ first, separator, second }).map(T, struct {
        pub fn call(value: meta.StructFromParsers(.{ first, separator, second })) T {
            return .{ value.@"0", value.@"2" };
        }
    });
}

const testing = std.testing;
const tag = @import("./bytes.zig").tag;
const char = @import("./chars.zig").char;
const whitespace = @import("./chars.zig").whitespace;

test "parsing def with abc before" {
    const parser = preceded(tag("abc"), tag("def"));

    const result = parser.run("abcdef", testing.allocator);
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("def", "")), result);
}

test "parsing abc with def after" {
    const parser = terminated(tag("abc"), tag("def"));

    const result = parser.run("abcdef", testing.allocator);
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("abc", "")), result);
}

test "parsing abc with \" around" {
    const parser = delimited(char('"'), tag("abc"), char('"'));

    const result = parser.run("\"abc\"", testing.allocator);
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("abc", "")), result);
}

test "parsing abc and def separated by ," {
    const parser = separated_pair(tag("abc"), tag(","), tag("def"));

    const result = parser.run("abc,def", testing.allocator);
    try testing.expectEqualDeep(ParseResult(struct { []const u8, []const u8 }, []const u8).Ok(Pair(struct { []const u8, []const u8 }, []const u8).init(.{ "abc", "def" }, "")), result);
}
