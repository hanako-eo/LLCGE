const std = @import("std");

pub const alloc = @import("./alloc.zig");
pub const branch = @import("./branch.zig");
pub const bytes = @import("./bytes.zig");
pub const chars = @import("./chars.zig");
pub const sequence = @import("./sequence.zig");

pub const errors = @import("./error.zig");

pub const meta = @import("./utils/meta.zig");

const ParseError = errors.ParseError;
const ParseErrorKind = errors.ParseErrorKind;

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

    pub fn min(self: Self) usize {
        return switch (self) {
            .many_times => 0,
            .at_least_once => 1,
            .at_least_n => |n| n,
            .range => |range| range.@"0",
        };
    }

    pub fn max(self: Self) usize {
        return switch (self) {
            .range => |range| range.@"1",
            // 0 means no max
            else => 0,
        };
    }
};

pub fn ParseResult(comptime T: type, comptime U: type) type {
    return Result(Pair(T, U), ParseError);
}

/// Type for create a parser
pub fn Parser(comptime T: type) type {
    return struct {
        // this constant is needed to be able to pass the resulting value to
        // the branch parsers
        pub const Result = T;

        // process function
        parse: fn ([]const u8, allocator: std.mem.Allocator) ParseResult(T, []const u8),

        const Self = @This();

        /// Initialize the parser with a `callable` argument.
        pub fn init(comptime parse: anytype) Self {
            const parse_function = comptime meta.callable(fn ([]const u8, std.mem.Allocator) ParseResult(T, []const u8), parse) orelse
                @compileError("the input parser is not callable (i.e. it's not a function or an other parser).");
            return Self{
                .parse = parse_function,
            };
        }

        /// Function used by the library to tell that a Parser(T) is callable,
        /// prefer to use run instead.
        pub fn call(comptime self: Self, input: []const u8, allocator: std.mem.Allocator) ParseResult(T, []const u8) {
            return self.parse(input, allocator);
        }

        /// Run the parser and return the parsing result and the unconsumed
        /// part of the input.
        pub inline fn run(comptime self: Self, input: []const u8, allocator: std.mem.Allocator) ParseResult(T, []const u8) {
            return self.parse(input, allocator);
        }

        /// Replace the parsing result of the parser by nothing.
        pub inline fn forgot(comptime self: Self) Parser(void) {
            return self.value(void, void{});
        }

        /// Put the parsing result into an array.
        pub inline fn into_array(comptime self: Self) Parser([]const T) {
            return self.map([]const T, struct {
                fn call(v: T) []const T {
                    return .{v};
                }
            }.call);
        }

        /// Replace the parsing result of the parser by a value of type `U`.
        pub inline fn value(comptime self: Self, comptime U: type, comptime v: U) Parser(U) {
            return self.map(U, struct {
                pub fn call(_: T) U {
                    return v;
                }
            });
        }

        /// Map the parsing result of the parser by a value of type `U`.
        pub fn map(comptime self: Self, comptime U: type, comptime mapping: anytype) Parser(U) {
            const map_fn = comptime meta.callable(fn (T) U, mapping) orelse @compileError("the map function must be callable.");
            return Parser(U).init(struct {
                pub fn call(input: []const u8, allocator: std.mem.Allocator) ParseResult(U, []const u8) {
                    const result = self.parse(input, allocator);
                    return switch (result) {
                        .ok => ParseResult(U, []const u8).Ok(Pair(U, []const u8).init(
                            map_fn(result.ok.first),
                            result.ok.second,
                        )),
                        .err => |err| ParseResult(U, []const u8).Err(err),
                    };
                }
            });
        }

        /// Execute normally the parser but if the result cannot be parser
        /// (an error occured during the parsing) the result will be null.
        pub fn opt(comptime self: Self) Parser(?T) {
            return Parser(?T).init(struct {
                pub fn call(input: []const u8, allocator: std.mem.Allocator) ParseResult(?T, []const u8) {
                    const result = self.parse(input, allocator);
                    return switch (result) {
                        .ok => |content| ParseResult(?T, []const u8).Ok(Pair(?T, []const u8).init(
                            content.first,
                            content.second,
                        )),
                        .err => ParseResult(?T, []const u8).Ok(Pair(?T, []const u8).init(
                            null,
                            input,
                        )),
                    };
                }
            });
        }

        /// Try to see if the parsing pass or not.
        pub fn recognize(comptime self: Self) Parser(bool) {
            return Parser(bool).init(struct {
                pub fn call(input: []const u8, allocator: std.mem.Allocator) ParseResult(bool, []const u8) {
                    const result = self.parse(input, allocator);
                    return ParseResult(bool, []const u8).Ok(Pair(bool, []const u8).init(
                        result == .ok,
                        input,
                    ));
                }
            });
        }

        /// Execute normally the parser without consumed the input.
        pub fn peek(comptime self: Self) Parser(T) {
            return Parser(T).init(struct {
                pub fn call(input: []const u8, allocator: std.mem.Allocator) ParseResult(T, []const u8) {
                    const result = self.parse(input, allocator);
                    return switch (result) {
                        .ok => |content| ParseResult(T, []const u8).Ok(Pair(T, []const u8).init(
                            content.first,
                            input,
                        )),
                        .err => result,
                    };
                }
            });
        }

        /// Execute normally the parser and check after if the result satify
        /// some conditions.
        pub fn satisfy_fn(comptime self: Self, comptime condition: anytype, comptime message: anytype) Parser(T) {
            const condition_fn = comptime meta.callable(fn (*const T) bool, condition) orelse @compileError("the condition must be callable.");
            const message_fn = comptime meta.callable(fn (*const T) []const u8, message) orelse @compileError("the message must be callable.");

            return Parser(T).init(struct {
                pub fn call(input: []const u8, allocator: std.mem.Allocator) ParseResult(T, []const u8) {
                    const result = self.parse(input, allocator);
                    return switch (result) {
                        .err => |err| .{ .err = err },
                        .ok => |content| if (!condition_fn(&content.first)) .{ .err = .{
                            .input = input,

                            .kind = .{ .satisfy = message_fn(&content.first) },
                        } } else result,
                    };
                }
            });
        }

        /// Execute normally the parser and check after if the result satify
        /// some conditions. (but take a literal instead of construct the message)
        pub inline fn satisfy(comptime self: Self, comptime condition: anytype, comptime message: []const u8) Parser(T) {
            return self.satisfy_fn(condition, struct {
                fn call(_: *const T) []const u8 {
                    return message;
                }
            }.call);
        }

        pub inline fn and_then(comptime self: Self, comptime other: anytype) Parser(meta.StructFromParsers(.{ self, other })) {
            return branch.chain(.{ self, other });
        }

        pub inline fn or_else(comptime self: Self, comptime other: anytype) Parser(T) {
            return branch.choice(.{ self, other });
        }
    };
}

pub const StringParser = Parser([]const u8);

test {
    _ = alloc;
    _ = branch;
    _ = bytes;
    _ = chars;
    _ = sequence;
}

const testing = std.testing;
const tag = bytes.tag;

test "parser with a custom behaviour" {
    const parser = Parser(u8).init(struct {
        pub fn call(input: []const u8, _: std.mem.Allocator) ParseResult(u8, []const u8) {
            return .{ .ok = Pair(u8, []const u8).init(input[0] + 1, input[1..]) };
        }
    });

    try std.testing.expectEqualDeep(ParseResult(u8, []const u8){ .ok = Pair(u8, []const u8).init('i', "ello") }, parser.run("hello", testing.allocator));
}

const Hello = struct {};
fn call_map(_: []const u8) Hello {
    return Hello{};
}

test "change the result of the parsing" {
    const parser = tag("hello");

    const result = parser.run("hello", testing.allocator);
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("hello", "")), result);

    const result2 = parser.map(Hello, call_map).run("hello", testing.allocator);
    try testing.expectEqualDeep(ParseResult(Hello, []const u8).Ok(Pair(Hello, []const u8).init(Hello{}, "")), result2);
}

test "optional parsing" {
    const parser = tag("hello").opt();

    const result = parser.run("hello", testing.allocator);
    try testing.expectEqualDeep(ParseResult(?[]const u8, []const u8).Ok(Pair(?[]const u8, []const u8).init("hello", "")), result);

    const result2 = parser.run("world", testing.allocator);
    try testing.expectEqualDeep(ParseResult(?[]const u8, []const u8).Ok(Pair(?[]const u8, []const u8).init(null, "world")), result2);
}

test "recognize without peeking parsing" {
    const parser = tag("hello").recognize();

    const result = parser.run("hello", testing.allocator);
    try testing.expectEqualDeep(ParseResult(bool, []const u8).Ok(Pair(bool, []const u8).init(true, "hello")), result);

    const result2 = parser.run("hi", testing.allocator);
    try testing.expectEqualDeep(ParseResult(bool, []const u8).Ok(Pair(bool, []const u8).init(false, "hi")), result2);
}

test "recognize with peeking parsing" {
    const parser = tag("hello").peek();

    const result = parser.run("hello", testing.allocator);
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("hello", "hello")), result);
}

fn safisfy_true(_: *const []const u8) bool {
    return true;
}

fn safisfy_false(_: *const []const u8) bool {
    return false;
}

test "parsing with satisfaction of condition" {
    const parser = tag("hello");

    const result = parser.satisfy(safisfy_true, "unexpected value").run("hello", testing.allocator);
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("hello", "")), result);

    const result2 = parser.satisfy(safisfy_false, "expected value").run("hello", testing.allocator);
    try testing.expectEqualDeep(ParseErrorKind{ .satisfy = "expected value" }, result2.err.kind);
}
