const std = @import("std");

const parser_zig = @import("./lib.zig");
const Parser = parser_zig.Parser;
const ParseResult = parser_zig.ParseResult;

const error_zig = @import("./error.zig");
const ParseErrorKind = error_zig.ParseErrorKind;

const meta_zig = @import("./utils/meta.zig");
const UnionFromParsers = meta_zig.UnionFromParsers;
const ParsersCommonValue = meta_zig.ParsersCommonValue;
const StructFromParsers = meta_zig.StructFromParsers;
const StructLen = meta_zig.StructLen;

const Result = @import("./utils/types.zig").Result;

const Pair = @import("utils").Pair;

/// Tests a list of parsers one by one until one succeeds. Each parser can have
/// it's own Result type.
pub fn select(comptime parsers: anytype) Parser(UnionFromParsers(parsers)) {
    const SelectUnion = UnionFromParsers(parsers);

    return Parser(SelectUnion).init(struct {
        pub fn call(input: []const u8) ParseResult(SelectUnion, []const u8) {
            const fields = @typeInfo(SelectUnion).@"union".fields;
            const size = StructLen(@TypeOf(parsers));

            // iterate over the parsers at compile time, as they do not
            // necessarily have the same memory size (and `parsers` is not an
            // array but a struct)
            inline for (parsers, 0..) |parser, i| {
                const result = parser.run(input);
                if (result == .ok) {
                    return ParseResult(SelectUnion, []const u8).Ok(Pair(SelectUnion, []const u8).init(@unionInit(SelectUnion, fields[i].name, result.ok.first), result.ok.second));
                }

                // test if it's the end of the loop and return the last err in
                // case of unsuccessful parsing
                if (comptime i + 1 == size) {
                    return ParseResult(SelectUnion, []const u8).Err(result.err);
                }
            }
        }
    });
}

/// Tests a list of parsers one by one until one succeeds. All parsers must
/// produce the same Result type.
pub fn choice(comptime parsers: anytype) Parser(ParsersCommonValue(parsers)) {
    const T = ParsersCommonValue(parsers);

    return Parser(T).init(struct {
        pub fn call(input: []const u8) ParseResult(T, []const u8) {
            const size = StructLen(@TypeOf(parsers));

            // iterate over the parsers at compile time, as they do not
            // necessarily have the same memory size (and `parsers` is not an
            // array but a struct)
            inline for (parsers, 0..) |parser, i| {
                const result = parser.run(input);
                if (result == .ok) {
                    return result;
                }

                // test if it's the end of the loop and return the last err in
                // case of unsuccessful parsing
                if (comptime i + 1 == size) {
                    return result;
                }
            }
        }
    });
}

/// Applies a list of parsers in the order.
pub fn chain(comptime parsers: anytype) Parser(StructFromParsers(parsers)) {
    const ChainStruct = StructFromParsers(parsers);
    const struct_fields = @typeInfo(ChainStruct).@"struct".fields;

    return Parser(ChainStruct).init(struct {
        pub fn call(initial_input: []const u8) ParseResult(ChainStruct, []const u8) {
            var final_result: ChainStruct = undefined;

            comptime var i = 0;
            var input = initial_input;

            // iterate over the constructed struct
            inline for (@typeInfo(@TypeOf(parsers)).@"struct".fields) |field| {
                const parser = @field(parsers, field.name);
                const result = parser.run(input);
                if (result == .err) {
                    return ParseResult(ChainStruct, []const u8).Err(result.err);
                }

                if (@TypeOf(result.ok.first) != void) {
                    @field(final_result, struct_fields[i].name) = result.ok.first;
                    i += 1;
                }
                
                input = result.ok.second;
            }

            return ParseResult(ChainStruct, []const u8).Ok(Pair(ChainStruct, []const u8).init(final_result, input));
        }
    });
}

const testing = std.testing;
const tag = @import("./bytes.zig").tag;
const whitespace = @import("./chars.zig").whitespace;

test "selection of the first element out of three" {
    const parser = select(.{ tag("hello"), tag("hi"), tag("hey") });
    const result = parser.run("hello");

    if (result == .err)
        std.debug.panic("unexpected result value, found Err({})", .{result.err});

    switch (result.ok.first) {
        .@"0" => |value| try testing.expectEqualStrings("hello", value),
        else => std.debug.panic("unexpected result value, expected 'hello'", .{}),
    }
}

test "selection of the second element out of three" {
    const parser = select(.{ tag("hello"), tag("hi"), tag("hey") });
    const result = parser.run("hi");

    if (result == .err)
        std.debug.panic("unexpected result value, found Err({})", .{result.err});

    switch (result.ok.first) {
        .@"1" => |value| try testing.expectEqualStrings("hi", value),
        else => std.debug.panic("unexpected result value, expected 'hi'", .{}),
    }
}

test "selection of the third element out of three" {
    const parser = select(.{ tag("hello"), tag("hi"), tag("hey") });
    const result = parser.run("hey");

    if (result == .err)
        std.debug.panic("unexpected result value, found Err({})", .{result.err});

    switch (result.ok.first) {
        .@"2" => |value| try testing.expectEqualStrings("hey", value),
        else => std.debug.panic("unexpected result value, expected 'hey'", .{}),
    }
}

test "selection of a non-existent element" {
    const parser = select(.{ tag("hello"), tag("hi"), tag("hey") });
    const result = parser.run("bonjour");

    if (result == .ok)
        std.debug.panic("unexpected result value, found OK({})", .{result.ok});

    try testing.expectEqualDeep(ParseErrorKind{ .tag = .{ .expected = "hey", .actual = "bon" } }, result.err.kind);
}

test "chain parsing with tuple" {
    const parser = chain(.{ tag("hello"), whitespace, tag("world") });
    const result = parser.run("hello world");

    if (result == .err)
        std.debug.panic("unexpected result value, found Err({})", .{result.err});

    try testing.expectEqualDeep(.{ "hello", ' ', "world" }, result.ok.first);
}

test "chain parsing with inside void field" {
    // chain need to remove void field to the result string
    const parser = chain(.{ tag("hello"), whitespace.forgot(), tag("world") });
    const result = parser.run("hello world");

    if (result == .err)
        std.debug.panic("unexpected result value, found Err({})", .{result.err});

    try testing.expectEqualDeep(.{ "hello", "world" }, result.ok.first);
}

test "chain parsing with struct" {
    // chain need to remove void field to the result string
    const parser = chain(.{ .hello = tag("hello"), .space = whitespace, .world = tag("world") });
    const result = parser.run("hello world");

    if (result == .err)
        std.debug.panic("unexpected result value, found Err({})", .{result.err});

    try testing.expectEqualDeep(@TypeOf(result.ok.first){ .hello = "hello", .space = ' ', .world = "world" }, result.ok.first);
}

test "chain parsing with struct and void field" {
    // chain need to remove void field to the result string
    const parser = chain(.{ .hello = tag("hello"), .space = whitespace.forgot(), .world = tag("world") });
    const result = parser.run("hello world");

    if (result == .err)
        std.debug.panic("unexpected result value, found Err({})", .{result.err});

    try testing.expectEqualDeep(@TypeOf(result.ok.first){ .hello = "hello", .world = "world" }, result.ok.first);
}

test "chose the first element out of three" {
    const parser = choice(.{ tag("hello"), tag("hi"), tag("hey") });
    const result = parser.run("hello");

    if (result == .err)
        std.debug.panic("unexpected result value, found Err({})", .{result.err});

    try testing.expectEqualDeep("hello", result.ok.first);
}
