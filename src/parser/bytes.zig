const std = @import("std");

const Context = @import("./context.zig");

const parser_zig = @import("./parser.zig");
const ParseError = parser_zig.ParseError;
const StringParser = parser_zig.StringParser;

const Result = @import("../utils/types.zig").Result;

const TagState = struct {
    tag: []const u8,

    const Self = @This();

    pub fn process(self: *Self, context: *Context) Result([]const u8, ParseError) {
        if (!std.mem.startsWith(u8, context.input, self.tag)) {
            return .{ .err = .{
                .cursor = context.dirty_cursor,
                .len = self.tag.len,
                .input = context.input,

                .kind = .{ .tag = self.tag },
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
    var parser = tag("hello");

    const result, const context = parser.run("hello world!");
    try testing.expectEqualDeep(Result([]const u8, ParseError){ .ok = "hello" }, result);
    try testing.expectEqual(context.dirty_cursor, context.cursor);
}
