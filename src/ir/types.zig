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

    pub fn size_of(self: Self) usize {
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
                .array => |a2| a1.size_of() == a2.size_of() and a1.child.castable(a2.child),
                .pointer => |p1| a1.child.castable(p1.child),
                else => false,
            },
            .pointer => |p1| switch (into) {
                .pointer => true,
                .int => |int1| p1.size_of() == int1.size_of(),
                else => false,
            },
            .int => |int1| switch (into) {
                .pointer => |p1| p1.size_of() == int1.size_of(),
                // TODO: add more verification ?
                .int => true,
                else => false,
            },
        }
    }
};
