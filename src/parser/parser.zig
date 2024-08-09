const std = @import("std");

const token_zig = @import("./token.zig");
const Token = token_zig.Token;
const TokenResult = token_zig.TokenResult;

fn Transformer(comptime P: type, comptime S: type) type {
    return struct {
        state: S,
        lambda: *const fn (*S, *Parser(P, S), []const u8) TokenResult(P, ParseError)
    };
}

pub fn StringParser(comptime S: type) type {
    return Parser([]const u8, S);
}
pub fn Parser(comptime T: type, comptime S: type) type {
    return struct {
        transformer: Transformer(T, S),

        dirty_cursor: usize,
        cursor: usize,

        const Self = @This();

        pub fn init(state: S, lambda: fn (*S, *Parser(T, S), []const u8) TokenResult(T, ParseError)) Self {
            return Self {
                .transformer = .{ .lambda = lambda, .state = state },
                .dirty_cursor = 0,
                .cursor = 0
            };
        }

        fn commit(self: *Self) void {
            self.cursor = self.dirty_cursor;
        }

        pub fn run_without_commit(self: *Self, input: []const u8) TokenResult(T, ParseError) {
            return self.transformer.lambda(&self.transformer.state, self, input);
        }

        pub fn run(self: *Self, input: []const u8) TokenResult(T, ParseError) {
            const result = self.run_without_commit(input);
            self.commit();
            return result;
        }

        // modifiers
        pub fn map(self: Self, comptime U: type, lambda: *const fn(T) U) Parser(U, MapState(T, U, S)) {
            const state = MapState(T, U, S) { .map = lambda, .parser = self };
            return Parser(U, MapState(T, U, S)).init(state, MapState(T, U, S).process);
        }
    };
}

pub const ParseError = struct {
    cursor: usize,
    len: usize,
    input: []const u8,

    kind: ParseErrorKind
};

pub const ParseErrorKind = union(enum) {
    tag: []const u8,
};

fn MapState(comptime T: type, comptime U: type, comptime S: type) type {
    return struct {
        map: *const fn(T) U,
        parser: Parser(T, S),

        const Self = @This();

        pub fn process(self: *Self, parser: *Parser(U, Self), input: []const u8) TokenResult(U, ParseError) {
            const result = self.parser.run_without_commit(input);
            return switch (result) {
                .err => |err| .{ .err = err },
                .ok => |token| blk: {
                    parser.dirty_cursor = self.parser.dirty_cursor;
                    parser.cursor = self.parser.cursor;

                    break :blk .{ .ok = Token(U).init(self.map(token.value)) };
                }
            };
        }
    };
}

const testing = std.testing;
test "import parsing tests" {
    _ = @import("./bytes.zig");
}

const Hello = struct {};
fn call_map(_: []const u8) Hello {
    return Hello {};
}

test "change the content a the token" {
    const tag = @import("./bytes.zig").tag;

    var parser = tag("hello");
    var map_parser = tag("hello").map(Hello, call_map);

    const result = parser.run("hello");
    try testing.expectEqualDeep(TokenResult([]const u8, ParseError){ .ok = Token([]const u8).init("hello") }, result);
    try testing.expectEqual(parser.dirty_cursor, parser.cursor);

    const result2 = map_parser.run("hello");
    try testing.expectEqualDeep(TokenResult(Hello, ParseError){ .ok = Token(Hello).init(Hello {}) }, result2);
    try testing.expectEqual(map_parser.dirty_cursor, map_parser.cursor);
}
