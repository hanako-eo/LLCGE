const std = @import("std");

pub const branch = @import("./branch.zig");
pub const bytes = @import("./bytes.zig");
pub const chars = @import("./chars.zig");
pub const sequence = @import("./sequence.zig");

pub const Context = @import("./context.zig");
pub const errors = @import("./error.zig");

const ParseError = errors.ParseError;
const ParseErrorKind = errors.ParseErrorKind;

const Result = @import("./utils/types.zig").Result;

const meta = @import("./utils/meta.zig");

const Pair = @import("utils").Pair;

pub fn ParseResult(comptime T: type, comptime U: type) type {
    return Result(Pair(T, U), ParseError);
}

/// Type for create a parser
pub fn Parser(comptime T: type) type {
    return struct {
        parse: fn([]const u8) ParseResult(T, []const u8),

        const Self = @This();

        pub fn init(comptime parse: anytype) Self {
            const parse_function = comptime meta.callable(fn([]const u8) ParseResult(T, []const u8), parse) orelse
                @compileError("The input parser is not callable (i.e. it's not a function or an other parser).");
            return Self{ .parse = parse_function };
        }

        pub fn call(comptime self: Self, input: []const u8) ParseResult(T, []const u8) {
            return self.parse(input);
        }

        pub inline fn run(comptime self: Self, input: []const u8) ParseResult(T, []const u8) {
            return self.parse(input);
        }

        pub inline fn forgot(comptime self: Self) Parser(void) {
            return self.value(void, void{});
        }

        pub inline fn into_array(comptime self: Self) Parser([]const T) {
            return self.map([]const T, struct {
                fn call(v: T) []const T {
                    return .{v};
                }
            }.call);
        }

        pub inline fn value(comptime self: Self, comptime U: type, comptime v: U) Parser(U) {
            return self.map(U, struct {
                pub fn call(_: T) U {
                    return v;
                }
            });
        }

        pub fn map(comptime self: Self, comptime U: type, comptime mapping: anytype) Parser(U) {
            const map_fn = comptime meta.callable(fn (T) U, mapping) orelse @compileError("The map function need to be callable.");
            return Parser(U).init(struct {
                pub fn call(input: []const u8) ParseResult(U, []const u8) {
                    const result = self.parse(input);
                    return switch (result) {
                        .ok => ParseResult(U, []const u8).Ok(Pair(U, []const u8).init(
                            map_fn(result.ok.first),
                            result.ok.second
                        )),
                        .err => |err| ParseResult(U, []const u8).Err(err)
                    };
                }
            });
        }

        pub fn opt(comptime self: Self) Parser(?T) {
            return Parser(?T).init(struct {
                pub fn call(input: []const u8) ParseResult(?T, []const u8) {
                    const result = self.parse(input);
                    return switch (result) {
                        .ok => |content| ParseResult(?T, []const u8).Ok(Pair(?T, []const u8).init(content.first, content.second)),
                        .err => ParseResult(?T, []const u8).Ok(Pair(?T, []const u8).init(null, input))
                    };
                }
            });
        }

        // TODO: ?
        // pub fn not(comptime self: Self) Parser(void, NotState(T, S)) {
        //     const state = NotState(T, S){ .parser = self };
        //     return Parser(void, NotState(T, S)).init(state, NotState(T, S).process);
        // }

        pub fn recognize(comptime self: Self) Parser(bool) {
            return Parser(bool).init(struct {
                pub fn call(input: []const u8) ParseResult(bool, []const u8) {
                    const result = self.parse(input);
                    return ParseResult(bool, []const u8).Ok(Pair(bool, []const u8).init(result == .ok, input));
                }
            });
        }

        pub fn peek(comptime self: Self) Parser(T) {
            return Parser(T).init(struct {
                pub fn call(input: []const u8) ParseResult(T, []const u8) {
                    const result = self.parse(input);
                    return switch (result) {
                        .ok => |content| ParseResult(T, []const u8).Ok(Pair(T, []const u8).init(content.first, input)),
                        .err => result
                    };
                }
            });
        }

        pub fn satisfy_fn(comptime self: Self, comptime condition: anytype, comptime message: anytype) Parser(T) {
            const condition_fn = comptime meta.callable(fn (*const T) bool, condition) orelse @compileError("The condition need to be callable.");
            const message_fn = comptime meta.callable(fn (*const T) []const u8, message) orelse @compileError("The message need to be callable.");

            return Parser(T).init(struct {
                pub fn call(input: []const u8) ParseResult(T, []const u8) {
                    const result = self.parse(input);
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

        pub inline fn satisfy(comptime self: Self, comptime condition: anytype, comptime message: []const u8) Parser(T) {
            return self.satisfy_fn(condition, struct {
                fn call(_: *const T) []const u8 {
                    return message;
                }
            }.call);
        }

        // pub fn finished(comptime self: Self) Parser(T, FinishedState(T, S)) {
        //     const result = self.parser.run_with_context_without_commit(context);
        //     if (predicate(context))
        //         return result;

        //     return .{ .err = .{
        //         .cursor = context.cursor,
        //         .len = 0,
        //         .input = context.input,

        //         .kind = .not_finished,
        //     } };
        // }

        // pub fn followed_by(comptime self: Self, lambda: anytype) Parser(T, FollowedByState(T, S)) {
        //     const state = FollowedByState(T, S){ .lambda = OwnedRef(fn (u8) bool).from_any(lambda), .parser = self };
        //     return Parser(T, FollowedByState(T, S)).init(state, FollowedByState(T, S).process);
        // }
    };
}

test "new parser ?" {
    const t = Parser(u8).init(struct {
        pub fn call(input: []const u8) ParseResult(u8, []const u8) {
            return .{ .ok = Pair(u8, []const u8).init(input[0], input[1..]) };
        }
    }).map(u8, struct {
        pub fn call(x: u8) u8 { return x + 1; } 
    }.call);

    try std.testing.expectEqualDeep(ParseResult(u8, []const u8) { .ok = Pair(u8, []const u8).init('i', "ello") }, t.parse("hello"));
}

pub const StringParser = Parser([]const u8);

test {
    // _ = branch;
    _ = bytes;
    _ = chars;
    // _ = sequence;
}

const testing = std.testing;
const tag = bytes.tag;

const Hello = struct {};
fn call_map(_: []const u8) Hello {
    return Hello{};
}

test "change the result of the parsing" {
    const parser = tag("hello");

    const result = parser.run("hello");
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("hello", "")), result);

    const result2 = parser.map(Hello, call_map).run("hello");
    try testing.expectEqualDeep(ParseResult(Hello, []const u8).Ok(Pair(Hello, []const u8).init(Hello{}, "")), result2);
}

test "optional parsing" {
    const parser = tag("hello").opt();

    const result = parser.run("hello");
    try testing.expectEqualDeep(ParseResult(?[]const u8, []const u8).Ok(Pair(?[]const u8, []const u8).init("hello", "")), result);

    const result2 = parser.run("world");
    try testing.expectEqualDeep(ParseResult(?[]const u8, []const u8).Ok(Pair(?[]const u8, []const u8).init(null, "world")), result2);
}

// test "not parsing" {
//     const parser = tag("hello").not();

//     const result = parser.run("hello");
//     try testing.expectEqualDeep(ParseErrorKind([]const u8){ .not = "hello" }, result.err.kind);

//     const result2 = parser.run("world");
//     try testing.expectEqualDeep(.ok, result2);
// }

test "recognize without peeking parsing" {
    const parser = tag("hello").recognize();

    const result = parser.run("hello");
    try testing.expectEqualDeep(ParseResult(bool, []const u8).Ok(Pair(bool, []const u8).init(true, "hello")), result);

    const result2 = parser.run("hi");
    try testing.expectEqualDeep(ParseResult(bool, []const u8).Ok(Pair(bool, []const u8).init(false, "hi")), result2);
}

test "recognize with peeking parsing" {
    const parser = tag("hello").peek();

    const result = parser.run("hello");
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

    const result = parser.satisfy(safisfy_true, "unexpected value").run("hello");
    try testing.expectEqualDeep(ParseResult([]const u8, []const u8).Ok(Pair([]const u8, []const u8).init("hello", "")), result);

    const result2 = parser.satisfy(safisfy_false, "expected value").run("hello");
    try testing.expectEqualDeep(ParseErrorKind{ .satisfy = "expected value" }, result2.err.kind);
}

// test "check if the parser parse all" {
//     const parser = tag("hello").finished();
//     const parser2 = tag("hello").finished_z();

//     const result = parser.run_without_commit("hello");
//     try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "hello" }, result);

//     const result2 = parser.run_without_commit("hello!");
//     try testing.expectEqualDeep(.not_finished, result2.err.kind);

//     const result3 = parser2.run_without_commit("hello");
//     try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "hello" }, result3);

//     const result4 = parser2.run_without_commit("hello!");
//     try testing.expectEqualDeep(.not_finished, result4.err.kind);
// }

// test "check if 'hello' is followed by a whitespace char or nothing" {
//     const parser = tag("hello").followed_by(std.ascii.isWhitespace);

//     const result = parser.run("hello");
//     try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "hello" }, result);

//     const result2 = parser.run("hello world");
//     try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "hello" }, result2);

//     const result3 = parser.run("helloo");
//     try testing.expectEqualDeep(ParseErrorKind{ .unexpected = 'o' }, result3.err.kind);
// }
