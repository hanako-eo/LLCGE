const std = @import("std");

const Context = @import("./context.zig");

const parser_zig = @import("./parser.zig");
const Parser = parser_zig.Parser;

const error_zig = @import("./error.zig");
const ParseError = error_zig.ParseError;
const ParseErrorKind = error_zig.ParseErrorKind;

const meta_zig = @import("../utils/meta.zig");
const getStructAttribute = meta_zig.getStructAttribute;
const CreateUnionEnum = meta_zig.CreateUnionEnum;
const UnionFromParsers = meta_zig.UnionFromParsers;
const LenOfParsers = meta_zig.LenOfParsers;

const Result = @import("../utils/types.zig").Result;

pub fn select(comptime parsers: anytype) Parser(UnionFromParsers(parsers), SelectState(@TypeOf(parsers), UnionFromParsers(parsers), LenOfParsers(parsers))) {
    const ParsersType = @TypeOf(parsers);
    const SelectUnion = UnionFromParsers(parsers);
    const size = LenOfParsers(parsers);

    const state = SelectState(ParsersType, SelectUnion, size){ .parsers = parsers };
    return Parser(SelectUnion, SelectState(ParsersType, SelectUnion, size)).init(state, SelectState(ParsersType, SelectUnion, size).process);
}

fn SelectState(comptime Ps: type, comptime T: type, comptime size: comptime_int) type {
    return struct {
        parsers: Ps,

        const Self = @This();
        pub const NotValue = void;

        pub fn process(self: Self, context: *Context) Result(T, ParseError(NotValue)) {
            const fields = @typeInfo(T).Union.fields;

            // iterate over the parsers at compile time, as they do not necessarily have the same memory size (and Ps is not an array but a struct)
            inline for (self.parsers, 0..) |p, i| {
                const result = p.runWithContext(context);
                if (result == .ok)
                    return .{ .ok = @unionInit(T, fields[i].name, result.ok) };

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

const testing = std.testing;
const tag = @import("./bytes.zig").tag;

test "selection of the first element out of three" {
    const parser = select(.{ tag("hello"), tag("hi"), tag("hey") });
    const result, const context = parser.run("hello");

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
    const result, const context = parser.run("hi");

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
    const result, const context = parser.run("hey");

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
    const result, const context = parser.run("bonjour");

    if (result == .ok)
        std.debug.panic("unexpected result value, found OK({})", .{result.ok});

    try testing.expectEqualDeep(ParseErrorKind(void){ .tag = .{ .expected = "hey", .actual = "bon" } }, result.err.kind);
    try testing.expectEqual(0, context.dirty_cursor);
}
