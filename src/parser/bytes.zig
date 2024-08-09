const std = @import("std");

const parser_zig = @import("./parser.zig");
const ParseError = parser_zig.ParseError;
const StringParser = parser_zig.StringParser;

const token_zig = @import("./token.zig");
const Token = token_zig.Token;
const TokenResult = token_zig.TokenResult;

const TagState = struct {
    tag: []const u8,

    const Self = @This();

    pub fn process(self: *Self, parser: *StringParser(Self), input: []const u8) TokenResult([]const u8, ParseError) {
        if (!std.mem.startsWith(u8, input, self.tag)) {
            return .{
                .err = .{
                    .cursor = parser.dirty_cursor,
                    .len = self.tag.len,
                    .input = input,

                    .kind = .{ .tag = self.tag },
                }
            };
        }

        const start_cursor = parser.dirty_cursor;
        parser.dirty_cursor += self.tag.len;

        return .{
            .ok = Token([]const u8).init(input[start_cursor..parser.dirty_cursor])
        };
    }
};

pub fn tag(expected_tag: []const u8) StringParser(TagState) {
    const parser = TagState { .tag = expected_tag };
    return StringParser(TagState).init(parser, TagState.process);
}

const testing = std.testing;
test "parsing tag" {
    var parser = tag("hello");

    const result = parser.run("hello world!");
    try testing.expectEqualDeep(TokenResult([]const u8, ParseError){ .ok = Token([]const u8).init("hello") }, result);

    try testing.expectEqual(parser.dirty_cursor, parser.cursor);
}
