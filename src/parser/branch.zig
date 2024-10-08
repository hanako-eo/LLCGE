const std = @import("std");

const Context = @import("./context.zig");

const parser_zig = @import("../parser.zig");
const Parser = parser_zig.Parser;

const error_zig = @import("./error.zig");
const ParseError = error_zig.ParseError;
const ParseErrorKind = error_zig.ParseErrorKind;

const meta_zig = @import("../utils/meta.zig");
const get_struct_attribute = meta_zig.get_struct_attribute;
const UnionFromParsers = meta_zig.UnionFromParsers;
const ParsersCommonValue = meta_zig.ParsersCommonValue;
const StructFromParsers = meta_zig.StructFromParsers;
const StructLen = meta_zig.StructLen;

const Result = @import("../utils/types.zig").Result;

pub fn SelectState(comptime Ps: type, comptime T: type) type {
    const size = StructLen(Ps);

    return struct {
        parsers: Ps,

        const Self = @This();
        pub const NotValue = void;

        pub fn process(self: Self, context: *Context) Result(T, ParseError(NotValue)) {
            const fields = @typeInfo(T).Union.fields;

            // iterate over the parsers at compile time, as they do not necessarily have the same memory size (and Ps is not an array but a struct)
            inline for (self.parsers, 0..) |p, i| {
                const result = p.run_with_context_without_commit(context);
                if (result == .ok) {
                    context.commit();
                    return .{ .ok = @unionInit(T, fields[i].name, result.ok) };
                }

                context.uncommit();
                if (i + 1 == size) {
                    return .{ .err = .{
                        .cursor = result.err.cursor,
                        .len = result.err.len,
                        .input = result.err.input,

                        .kind = switch (result.err.kind) {
                            .not => .not,
                            else => result.err.kind,
                        },
                    } };
                }
            }
        }
    };
}

pub fn select(comptime parsers: anytype) Parser(UnionFromParsers(parsers), SelectState(@TypeOf(parsers), UnionFromParsers(parsers))) {
    const ParsersType = @TypeOf(parsers);
    const SelectUnion = UnionFromParsers(parsers);

    const state = SelectState(ParsersType, SelectUnion){ .parsers = parsers };
    return Parser(SelectUnion, SelectState(ParsersType, SelectUnion)).init(state, SelectState(ParsersType, SelectUnion).process);
}

pub fn ChoiceState(comptime Ps: type, comptime T: type) type {
    const size = StructLen(Ps);

    return struct {
        parsers: Ps,

        const Self = @This();
        pub const NotValue = void;

        pub fn call(self: Self, c: u8) bool {
            inline for (self.parsers) |p| {
                if (p.call(c))
                    return true;
            }

            return false;
        }

        pub fn process(self: Self, context: *Context) Result(T, ParseError(NotValue)) {
            // iterate over the parsers at compile time, as they do not necessarily have the same memory size (and Ps is not an array but a struct)
            inline for (self.parsers, 0..) |p, i| {
                const result = p.run_with_context_without_commit(context);
                if (result == .ok) {
                    context.commit();
                    return result;
                }

                context.uncommit();
                if (i + 1 == size) {
                    return .{ .err = .{
                        .cursor = result.err.cursor,
                        .len = result.err.len,
                        .input = result.err.input,

                        .kind = switch (result.err.kind) {
                            .not => .not,
                            else => result.err.kind,
                        },
                    } };
                }
            }
        }
    };
}

pub fn choice(comptime parsers: anytype) Parser(ParsersCommonValue(parsers), ChoiceState(@TypeOf(parsers), ParsersCommonValue(parsers))) {
    const ParsersType = @TypeOf(parsers);
    const CommonValue = ParsersCommonValue(parsers);

    const state = ChoiceState(ParsersType, CommonValue){ .parsers = parsers };
    return Parser(CommonValue, ChoiceState(ParsersType, CommonValue)).init(state, ChoiceState(ParsersType, CommonValue).process);
}

pub fn ChainState(comptime Ps: type, comptime T: type) type {
    return struct {
        parsers: Ps,

        const Self = @This();
        pub const NotValue = void;

        pub fn process(self: Self, context: *Context) Result(T, ParseError(NotValue)) {
            const fields = @typeInfo(T).Struct.fields;
            var final_result: T = undefined;

            // iterate over the parsers at compile time, as they do not necessarily have the same memory size (and Ps is not an array but a struct)
            comptime var i = 0;
            inline for (@typeInfo(Ps).Struct.fields) |parsers_field| {
                const p = @field(self.parsers, parsers_field.name);
                const parse_result = p.run_with_context_without_commit(context);
                if (parse_result == .err) {
                    context.uncommit();
                    return .{ .err = .{
                        .cursor = parse_result.err.cursor,
                        .len = parse_result.err.len,
                        .input = parse_result.err.input,

                        .kind = switch (parse_result.err.kind) {
                            .not => .not,
                            else => parse_result.err.kind,
                        },
                    } };
                }

                if (@TypeOf(parse_result.ok) != void) {
                    @field(final_result, fields[i].name) = parse_result.ok;
                    i += 1;
                }
                context.commit();
            }

            return .{ .ok = final_result };
        }
    };
}

pub fn chain(comptime parsers: anytype) Parser(StructFromParsers(parsers), ChainState(@TypeOf(parsers), StructFromParsers(parsers))) {
    const ParsersType = @TypeOf(parsers);
    const ChainStruct = StructFromParsers(parsers);

    const state = ChainState(ParsersType, ChainStruct){ .parsers = parsers };
    return Parser(ChainStruct, ChainState(ParsersType, ChainStruct)).init(state, ChainState(ParsersType, ChainStruct).process);
}

const testing = std.testing;
const tag = @import("./bytes.zig").tag;
const whitespace = @import("./chars.zig").whitespace;

test "selection of the first element out of three" {
    const parser = select(.{ tag("hello"), tag("hi"), tag("hey") });
    const result, const context = parser.run_without_commit("hello");

    if (result == .err)
        std.debug.panic("unexpected result value, found Err({})", .{result.err});

    try testing.expectEqual(5, context.cursor);
    switch (result.ok) {
        .@"0" => |value| try testing.expectEqualStrings("hello", value),
        else => std.debug.panic("unexpected result value, expected 'hello'", .{}),
    }
}

test "selection of the second element out of three" {
    const parser = select(.{ tag("hello"), tag("hi"), tag("hey") });
    const result, const context = parser.run_without_commit("hi");

    if (result == .err)
        std.debug.panic("unexpected result value, found Err({})", .{result.err});

    try testing.expectEqual(2, context.cursor);
    switch (result.ok) {
        .@"1" => |value| try testing.expectEqualStrings("hi", value),
        else => std.debug.panic("unexpected result value, expected 'hi'", .{}),
    }
}

test "selection of the third element out of three" {
    const parser = select(.{ tag("hello"), tag("hi"), tag("hey") });
    const result, const context = parser.run_without_commit("hey");

    if (result == .err)
        std.debug.panic("unexpected result value, found Err({})", .{result.err});

    try testing.expectEqual(3, context.cursor);
    switch (result.ok) {
        .@"2" => |value| try testing.expectEqualStrings("hey", value),
        else => std.debug.panic("unexpected result value, expected 'hey'", .{}),
    }
}

test "selection of a non-existent element" {
    const parser = select(.{ tag("hello"), tag("hi"), tag("hey") });
    const result, const context = parser.run_without_commit("bonjour");

    if (result == .ok)
        std.debug.panic("unexpected result value, found OK({})", .{result.ok});

    try testing.expectEqualDeep(ParseErrorKind(void){ .tag = .{ .expected = "hey", .actual = "bon" } }, result.err.kind);
    try testing.expectEqual(0, context.dirty_cursor);
}

test "chain parsing with tuple" {
    const parser = chain(.{ tag("hello"), whitespace, tag("world") }).finished();
    const result, const context = parser.run_without_commit("hello world");

    if (result == .err)
        std.debug.panic("unexpected result value, found Err({})", .{result.err});

    try testing.expectEqualDeep(.{ "hello", ' ', "world" }, result.ok);
    try testing.expectEqual(context.dirty_cursor, context.cursor);
    try testing.expectEqual(11, context.dirty_cursor);
}

test "chain parsing with inside void field" {
    // chain need to remove void field to the result string
    const parser = chain(.{ tag("hello"), whitespace.forgot(), tag("world") }).finished();
    const result, const context = parser.run_without_commit("hello world");

    if (result == .err)
        std.debug.panic("unexpected result value, found Err({})", .{result.err});

    try testing.expectEqualDeep(.{ "hello", "world" }, result.ok);
    try testing.expectEqual(context.dirty_cursor, context.cursor);
    try testing.expectEqual(11, context.dirty_cursor);
}

test "chain parsing with struct" {
    // chain need to remove void field to the result string
    const parser = chain(.{ .hello = tag("hello"), .space = whitespace, .world = tag("world") }).finished();
    const result, const context = parser.run_without_commit("hello world");

    if (result == .err)
        std.debug.panic("unexpected result value, found Err({})", .{result.err});

    try testing.expectEqualDeep(meta_zig.get_struct_attribute(@TypeOf(parser), "Value"){ .hello = "hello", .space = ' ', .world = "world" }, result.ok);
    try testing.expectEqual(context.dirty_cursor, context.cursor);
    try testing.expectEqual(11, context.dirty_cursor);
}

test "chain parsing with struct and void field" {
    // chain need to remove void field to the result string
    const parser = chain(.{ .hello = tag("hello"), .space = whitespace.forgot(), .world = tag("world") }).finished();
    const result, const context = parser.run_without_commit("hello world");

    if (result == .err)
        std.debug.panic("unexpected result value, found Err({})", .{result.err});

    try testing.expectEqualDeep(meta_zig.get_struct_attribute(@TypeOf(parser), "Value"){ .hello = "hello", .world = "world" }, result.ok);
    try testing.expectEqual(context.dirty_cursor, context.cursor);
    try testing.expectEqual(11, context.dirty_cursor);
}

test "chose the first element out of three" {
    const parser = choice(.{ tag("hello"), tag("hi"), tag("hey") });
    const result, const context = parser.run_without_commit("hello");

    if (result == .err)
        std.debug.panic("unexpected result value, found Err({})", .{result.err});

    try testing.expectEqualDeep(Result([]const u8, ParseError(void)){ .ok = "hello" }, result);
    try testing.expectEqual(5, context.cursor);
}
