const std = @import("std");

const ArrayType = @import("./types/array.zig");
const PointerType = @import("./types/pointer.zig");
const IntType = @import("./types/int.zig");

pub const Type = union(enum) {
    array: ArrayType,
    pointer: PointerType,
    int: IntType,
    label: void,
    void: void,

    const Self = @This();

    pub fn eq(self: Self, other: Self) bool {
        return @intFromEnum(self) == @intFromEnum(other) and switch (self) {
            .array => |array| array.eq(other.array),
            .pointer => |pointer| pointer.eq(other.pointer),
            .int => |int| int.eq(other.int),
            .label, .void => true,
        };
    }

    pub fn sizeOf(self: Self) usize {
        return switch (self) {
            .label, .void => 0,
            inline else => |t| t.sizeOf(),
        };
    }

    pub fn castable(self: Self, into: Self) bool {
        switch (self) {
            .label => false,
            .void => into == .void,
            .array => |a1| switch (into) {
                .array => |a2| a1.sizeOf() == a2.sizeOf() and a1.child.castable(a2.child),
                .pointer => |p1| a1.child.castable(p1.child),
                else => false,
            },
            .pointer => |p1| switch (into) {
                .pointer => true,
                .int => |int1| p1.sizeOf() == int1.sizeOf(),
                else => false,
            },
            .int => |int1| switch (into) {
                .pointer => |p1| p1.sizeOf() == int1.sizeOf(),
                // TODO: add more verification ?
                .int => true,
                else => false,
            },
        }
    }

    pub fn format(
        self: Self,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try switch (self) {
            .array => |array| writer.print("{}[{}]", .{ array.child, array.size }),
            .pointer => |ptr| writer.print("{}*", .{ptr.child}),
            .int => |int| writer.print("{s}int{}", .{ if (int.signed) "s" else "u", int.bits }),
            .label => writer.writeAll("label"),
            .void => writer.writeAll("void"),
        };
    }
};
