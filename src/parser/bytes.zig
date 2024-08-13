const std = @import("std");

const Context = @import("./context.zig");

const parser_zig = @import("../parser.zig");
const StringParser = parser_zig.StringParser;

const error_zig = @import("./error.zig");
const ParseError = error_zig.ParseError;
const ParseErrorKind = error_zig.ParseErrorKind;

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

        const start_cursor = context.dirty_cursor;
        context.dirty_cursor += self.tag.len;

        return .{ .ok = context.input[start_cursor..context.dirty_cursor] };
    }
};

pub fn tag(expected_tag: []const u8) StringParser(TagState) {
    const parser = TagState{ .tag = expected_tag };
    return StringParser(TagState).init(parser, TagState.process);
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
