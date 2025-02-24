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

pub const LoopPattern = union(enum) {
    /// Ensures that the parsing loop is called as many times as possible.
    many_times,
    /// Ensures that the parsing loop is called at least once.
    at_least_once,
    /// Ensures that the parsing loop is called at least N times
    at_least_n: usize,
    /// Ensures that the parsing loop is called between N and M times
    range: struct { usize, usize },

    const Self = @This();

    fn min(self: Self) usize {
        return switch (self) {
            .many_times => 0,
            .at_least_once => 1,
            .at_least_n => |n| n,
            .range => |range| range.@"0",
        };
    }

    fn max(self: Self) usize {
        return switch (self) {
            .range => |range| range.@"1",
            // 0 means no max
            else => 0,
        };
    }
};

inline fn length(comptime T: type, value: T) usize {
    if (@typeInfo(T) == .array) return value.len;
    return 1;
}

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

            return ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init(
                expected_tag,
                input[expected_tag.len..],
            ));
        }
    });
}

fn take_while_parser(comptime T: type, comptime predicate: fn ([]const u8) ParseResult(T, []const u8), comptime pattern: LoopPattern) StringParser {
    const min = pattern.min();
    const max = pattern.max();
    return StringParser.init(struct {
        pub fn call(input: []const u8) ParseResult([]const u8, []const u8) {
            var cursor: usize = 0;
            var iteration: usize = 0;
            var final_input = input;
            while (cursor < input.len) {
                if (max > 0 and iteration == max)
                    break;

                switch (predicate(final_input)) {
                    .err => break,
                    .ok => |pair| {
                        final_input = pair.second;
                        cursor += length(T, pair.first);
                    },
                }
                iteration += 1;
            }

            if (min > iteration)
                return ParseResult([]const u8, []const u8).Err(.{ .input = input, .kind = .{
                    .unsatify_min_patern = .{
                        .expected = min,
                        .actual = iteration,
                    },
                } });

            return ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init(
                input[0..cursor],
                final_input,
            ));
        }
    });
}

fn take_while_char(comptime predicate: fn (u8) bool, comptime pattern: LoopPattern) StringParser {
    const min = pattern.min();
    const max = pattern.max();
    return StringParser.init(struct {
        pub fn call(input: []const u8) ParseResult([]const u8, []const u8) {
            var cursor: usize = 0;
            while (cursor < input.len and predicate(input[cursor])) {
                if (max > 0 and cursor == max)
                    break;

                cursor += 1;
            }

            if (min > cursor)
                return ParseResult([]const u8, []const u8).Err(.{ .input = input, .kind = .{
                    .unsatify_min_patern = .{
                        .expected = min,
                        .actual = cursor,
                    },
                } });

            return ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init(
                input[0..cursor],
                input[cursor..],
            ));
        }
    });
}

/// Parse the input while the callable parser return a result.
pub fn take_while(comptime parser: anytype, comptime pattern: LoopPattern) StringParser {
    if (comptime meta.callable(fn ([]const u8) ParseResult([]const u8, []const u8), parser)) |predicate| {
        return take_while_parser([]const u8, predicate, pattern);
    } else if (comptime meta.callable(fn ([]const u8) ParseResult(u8, []const u8), parser)) |predicate| {
        return take_while_parser(u8, predicate, pattern);
    } else if (comptime meta.callable(fn (u8) bool, parser)) |predicate| {
        return take_while_char(predicate, pattern);
    }

    @compileError("the input parser must be callable like a 'fn([]const u8) ParseResult([]const u8, []const u8)' or 'fn([]const u8) ParseResult(u8, []const u8)' or 'fn(u8) bool'");
}

/// Parse the input until the callable parser return a result.
pub fn take_until(comptime parser: anytype, comptime pattern: LoopPattern) StringParser {
    const predicate = if (comptime (meta.callable(fn ([]const u8) ParseResult([]const u8, []const u8), parser) orelse meta.callable(fn ([]const u8) ParseResult(u8, []const u8), parser))) |predicate| struct {
        fn call(input: []const u8) bool {
            return predicate(input) == .ok;
        }
    }.call else if (comptime meta.callable(fn (u8) bool, parser)) |predicate| struct {
        fn call(input: []const u8) bool {
            return predicate(input[0]);
        }
    }.call else @compileError("the input parser must be callable like a 'fn([]const u8) ParseResult([]const u8, []const u8' or 'fn([]const u8) ParseResult(u8, []const u8)' or 'fn(u8) bool'");

    const min = pattern.min();
    const max = pattern.max();
    return StringParser.init(struct {
        pub fn call(input: []const u8) ParseResult([]const u8, []const u8) {
            var cursor: usize = 0;
            while (cursor < input.len and !predicate(input[cursor..])) {
                if (max > 0 and cursor == max)
                    break;

                cursor += 1;
            }

            if (min > cursor)
                return ParseResult([]const u8, []const u8).Err(.{ .input = input, .kind = .{
                    .unsatify_min_patern = .{
                        .expected = min,
                        .actual = cursor,
                    },
                } });

            return ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init(
                input[0..cursor],
                input[cursor..],
            ));
        }
    });
}

/// parse the input as long as this is possible and there is no character to escape.
pub fn escaped(comptime raw_parser: anytype, comptime control_char: u8, comptime raw_escapable: anytype) StringParser {
    const parser = comptime meta.callable(fn ([]const u8) ParseResult([]const u8, []const u8), raw_parser) orelse
        @compileError("the input parser must be callable.");
    const escapable, const EscapeType = if (comptime meta.callable(fn ([]const u8) ParseResult([]const u8, []const u8), raw_escapable)) |escapable_str|
        .{ escapable_str, []const u8 }
    else if (comptime meta.callable(fn ([]const u8) ParseResult(u8, []const u8), raw_escapable)) |escapable_char|
        .{ escapable_char, u8 }
    else
        @compileError("the input escapable parser must be callable.");

    return StringParser.init(struct {
        fn process_escape(input: []const u8) ?ParseResult(usize, []const u8) {
            if (input.len == 0 or input[0] != control_char)
                return null;

            if (input.len == 1)
                return ParseResult(usize, []const u8).Err(.{
                    .input = input,
                    .kind = .finished,
                });

            return switch (escapable(input[1..])) {
                .ok => |pair| ParseResult(usize, []const u8).Ok(Pair(usize, []const u8).init(
                    length(EscapeType, pair.first) + 1,
                    pair.second,
                )),
                .err => |err| ParseResult(usize, []const u8).Err(err),
            };
        }

        fn process_parser(input: []const u8) ?ParseResult(usize, []const u8) {
            if (input.len == 0)
                return null;

            return switch (parser(input)) {
                .ok => |pair| ParseResult(usize, []const u8).Ok(Pair(usize, []const u8).init(
                    pair.first.len,
                    pair.second,
                )),
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
                .err => |err| return ParseResult([]const u8, []const u8).Err(err),
                .ok => |pair| cursor += pair.first,
            };

            if (escaped_result) |r| switch (r) {
                .err => |err| return ParseResult([]const u8, []const u8).Err(err),
                .ok => |pair| cursor += pair.first,
            };

            return ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init(
                input[0..cursor],
                input[cursor..],
            ));
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

    const parser = take_while(std.ascii.isAlphabetic, .many_times);
    const parser2 = take_while(alpha, .many_times);
    const parser3 = take_while(alpha, .at_least_once);
    const parser4 = take_while(alpha, .{ .range = .{ 0, 2 } });
    const parser5 = take_while(std.ascii.isAlphabetic, .{ .range = .{ 1, 2 } });

    const result = parser.run("hello");
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("hello", "")), result);

    const result2 = parser2.run("hello");
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("hello", "")), result2);

    const result3 = parser3.run("hello");
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("hello", "")), result3);

    const result4 = parser3.run("");
    try testing.expectEqualDeep(ParseErrorKind{ .unsatify_min_patern = .{ .expected = 1, .actual = 0 } }, result4.err.kind);

    const result5 = parser4.run("hello");
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("he", "llo")), result5);

    const result6 = parser5.run("");
    try testing.expectEqualDeep(ParseErrorKind{ .unsatify_min_patern = .{ .expected = 1, .actual = 0 } }, result6.err.kind);

    const result7 = parser5.run("hello");
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("he", "llo")), result7);
}

test "parsing until is a num" {
    const digit = @import("./chars.zig").digit;

    const parser = take_until(std.ascii.isDigit, .many_times);
    const parser2 = take_until(digit, .many_times);
    const parser3 = take_until(digit, .at_least_once);
    const parser4 = take_until(digit, .{ .range = .{ 0, 2 } });

    const result = parser.run("hello0world");
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("hello", "0world")), result);

    const result2 = parser.run("0world");
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("", "0world")), result2);

    const result3 = parser2.run("hello0world");
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("hello", "0world")), result3);

    const result4 = parser3.run("hello0world");
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("hello", "0world")), result4);

    const result5 = parser3.run("h0world");
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("h", "0world")), result5);

    const result6 = parser3.run("0world");
    try testing.expectEqualDeep(ParseErrorKind{ .unsatify_min_patern = .{ .expected = 1, .actual = 0 } }, result6.err.kind);

    const result7 = parser4.run("hello0world");
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("he", "llo0world")), result7);
}

test "parsing number and escape ' with \\" {
    const char = @import("./chars.zig").char;
    // const digit = @import("./chars.zig").digit;

    const parser = escaped(take_while(std.ascii.isDigit, .many_times), '\\', char('\''));

    const result = parser.run("123");
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("123", "")), result);

    const result2 = parser.run("123 ");
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("123", " ")), result2);

    const result3 = parser.run("123\\'");
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("123\\'", "")), result3);

    const result4 = parser.run("123\\'456");
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("123\\'456", "")), result4);

    const result5 = parser.run("\\'456");
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("\\'456", "")), result5);

    const result6 = parser.run("\\'123\\'456");
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("\\'123\\'456", "")), result6);

    const result7 = parser.run("123\\");
    try testing.expectEqualDeep(.finished, result7.err.kind);

    const result8 = parser.run("123\\?");
    try testing.expectEqualDeep(ParseErrorKind{ .char = .{ .expected = '\'', .actual = '?' } }, result8.err.kind);
}
