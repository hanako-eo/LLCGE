const std = @import("std");

const parser_zig = @import("./lib.zig");
const Parser = parser_zig.Parser;
const ParseResult = parser_zig.ParseResult;
const StringParser = parser_zig.StringParser;

const error_zig = @import("./error.zig");
const ParseErrorKind = error_zig.ParseErrorKind;

const meta = @import("./utils/meta.zig");

const Result = @import("./utils/types.zig").Result;

const Pair = @import("utils").Pair;

/// Parse a list of chained chars.
pub fn tag(comptime expected_tag: []const u8) StringParser {
    return StringParser.init(struct {
        pub fn call(input: []const u8) ParseResult([]const u8, []const u8) {
            if (!std.mem.startsWith(u8, input, expected_tag)) {
                const cursor_end = @min(input.len, expected_tag.len);
                return ParseResult([]const u8, []const u8).Err(.{
                    .input = input,

                    .kind = .{ .tag = .{ .expected = expected_tag, .actual = input[0..cursor_end] } },
                });
            }

            return ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init(expected_tag, input[expected_tag.len..]));
        }
    });
}

fn take_while_parser(comptime T: type, comptime predicate: fn([]const u8) ParseResult(T, []const u8)) StringParser {
    return StringParser.init(struct {
        pub fn call(input: []const u8) ParseResult([]const u8, []const u8) {
            var cursor: usize = 0;
            var final_input = input;
            while (cursor < input.len) {
                switch (predicate(final_input)) {
                    .err => break,
                    .ok => |pair| {
                        final_input = pair.second;
                        cursor += if (T == u8) 1
                            else if (T == []const u8) pair.first.len
                            else @compileError("T must be a 'u8' or '[]const u8'");
                    }
                }
            }

            return ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init(input[0..cursor], final_input));
        }
    });
}

fn take_while_char(comptime predicate: fn(u8) bool) StringParser {
    return StringParser.init(struct {
        pub fn call(input: []const u8) ParseResult([]const u8, []const u8) {
            var cursor: usize = 0;
            while (cursor < input.len and predicate(input[cursor])) {
                cursor += 1;
            }

            return ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init(input[0..cursor], input[cursor..]));
        }
    });
}

/// Parse the input while the callable parser return a result.
pub fn take_while(comptime parser: anytype) StringParser {
    if (comptime meta.callable(fn([]const u8) ParseResult([]const u8, []const u8), parser)) |predicate| {
        return take_while_parser([]const u8, predicate);
    } else if (comptime meta.callable(fn([]const u8) ParseResult(u8, []const u8), parser)) |predicate| {
        return take_while_parser(u8, predicate);
    } else if (comptime meta.callable(fn(u8) bool, parser)) |predicate| {
        return take_while_char(predicate);
    }

    @compileError("the input parser must be callable like a 'fn([]const u8) ParseResult([]const u8, []const u8)' or 'fn([]const u8) ParseResult(u8, []const u8)' or 'fn(u8) bool'");
}

/// Parse the input until the callable parser return a result.
pub fn take_until(comptime parser: anytype) StringParser {
    const predicate = if (comptime (meta.callable(fn([]const u8) ParseResult([]const u8, []const u8), parser) orelse meta.callable(fn([]const u8) ParseResult(u8, []const u8), parser))) |predicate| struct {
        fn call(input: []const u8) bool {
            return predicate(input) == .ok;
        }
    }.call
    else if (comptime meta.callable(fn(u8) bool, parser)) |predicate|  struct {
        fn call(input: []const u8) bool {
            return predicate(input[0]);
        }
    }.call
    else @compileError("the input parser must be callable like a 'fn([]const u8) ParseResult([]const u8, []const u8' or 'fn([]const u8) ParseResult(u8, []const u8)' or 'fn(u8) bool'");

    return StringParser.init(struct {
        pub fn call(input: []const u8) ParseResult([]const u8, []const u8) {
            var cursor: usize = 0;
            while (cursor < input.len and !predicate(input[cursor..])) {
                cursor += 1;
            }

            return ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init(input[0..cursor], input[cursor..]));
        }
    });
}

/// parse the input as long as this is possible and there is no character to escape.
pub fn escaped(comptime raw_parser: anytype, comptime control_char: u8, comptime raw_escapable: anytype) StringParser {
    const parser = comptime meta.callable(fn([]const u8) ParseResult([]const u8, []const u8), raw_parser) orelse @compileError("the input parser must be callable.");
    const escapable = comptime meta.callable(fn([]const u8) ParseResult([]const u8, []const u8), raw_escapable) orelse @compileError("the input escapable parser must be callable.");

    return StringParser.init(struct {
        fn process_escape(input: []const u8) ?ParseResult([]const u8, []const u8) {
            if (input.len == 0 or input[0] != control_char)
                return null;

            return switch (escapable(input[1..])) {
                .ok => |pair| ParseResult(usize, []const u8).Ok(Pair(usize, []const u8).init(pair.first.len + 1, pair.second)),
                .err => |err| ParseResult(usize, []const u8).Err(err),
            };
        }

        fn process_parser(input: []const u8) ?ParseResult(usize, []const u8) {
            if (input.len == 0)
                return null;

            return switch (parser(input)) {
                .ok => |pair| ParseResult(usize, []const u8).Ok(Pair(usize, []const u8).init(pair.first.len, pair.second)),
                .err => |err| ParseResult(usize, []const u8).Err(err),
            };
        }

        pub fn call(input: []const u8) ParseResult([]const u8, []const u8) {
            var cursor: usize = 0;
            var final_input = input;
            var result = process_parser(input);
            if (result != null and result.? == .ok) {
                final_input = result.?.ok.second;
            }
            var escaped_result = process_escape(final_input);

            while (escaped_result != null and escaped_result.? != .err) {
                if (result != null and result.? == .ok)
                    cursor += result.?.ok.first;
                cursor += escaped_result.?.ok.first;
                final_input = escaped_result.?.ok.second;

                result = process_parser(final_input);
                if (result != null and result.? == .ok) {
                    final_input = result.?.ok.second;
                }
                escaped_result = process_escape(final_input);
            }

            if (result) |r| switch (r) {
                .err => |err| return ParseResult(usize, []const u8).Err(err),
                .ok => |pair| cursor += pair.first
            };

            if (escaped_result) |r| switch (r) {
                .err => |err| return ParseResult(usize, []const u8).Err(err),
                .ok => |pair| cursor += pair.first
            };

            return ParseResult([]const u8, []const u8).Ok(Pair(usize, []const u8).init(input[0..cursor], input[cursor..]));
        }
    });
}

const testing = std.testing;

test "parsing tag" {
    const parser = tag("hello");

    const result = parser.run("hello world!");
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("hello", " world!")), result);

    const result2 = parser.run("helllo world!");
    try testing.expectEqualDeep(ParseErrorKind{ .tag = .{ .expected = "hello", .actual = "helll" } }, result2.err.kind);

    const result3 = parser.run("hi!");
    try testing.expectEqualDeep(ParseErrorKind{ .tag = .{ .expected = "hello", .actual = "hi!" } }, result3.err.kind);
}

test "parsing while is a alpha" {
    const alpha = @import("./chars.zig").alpha;

    const parser = take_while(std.ascii.isAlphabetic);
    const parser2 = take_while(alpha);

    const result = parser.run("hello");
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("hello", "")), result);

    const result2 = parser2.run("hello");
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("hello", "")), result2);
}

test "parsing until is a num" {
    const digit = @import("./chars.zig").digit;

    const parser = take_until(std.ascii.isDigit);
    const parser2 = take_until(digit);

    const result = parser.run("hello0world");
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("hello", "0world")), result);

    const result2 = parser2.run("hello0world");
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("hello", "0world")), result2);
}

// test "parsing number and escape ' with \\" {
//     const char = @import("./chars.zig").char;
//     // const digit = @import("./chars.zig").digit;

//     const parser = escaped(take_while(std.ascii.isDigit), '\\', char('\''));

//     const result, _ = parser.run("123");
//     try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("123", "")), result);

//     const result2, _ = parser.run("123 ");
//     try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("123", "")), result2);

//     const result3, _ = parser.run("123\\'");
//     try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("123\\'", "")), result3);

//     const result4, _ = parser.run("123\\'456");
//     try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("123\\'456", "")), result4);

//     const result5, _ = parser.run("\\'456");
//     try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("\\'456", "")), result5);

//     const result6, _ = parser.run("\\'123\\'456");
//     try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("\\'123\\'456", "")), result6);

//     const result7, _ = parser.run("123\\");
//     try testing.expectEqualDeep(.finished, result7.err.kind);

//     const result8, _ = parser.run("123\\?");
//     try testing.expectEqualDeep(ParseErrorKind{ .char = .{ .expected = '\'', .actual = '?' } }, result8.err.kind);
// }
