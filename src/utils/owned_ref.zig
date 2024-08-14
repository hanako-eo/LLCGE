const std = @import("std");
const meta_zig = @import("./meta.zig");
const getReturnType = meta_zig.getReturnType;
const PtrTypeOf = meta_zig.PtrTypeOf;

pub fn OwnedRef(comptime T: type) type {
    return union(enum) {
        owned: T,
        borrowed: *const T,

        const Self = @This();

        pub fn fromAny(comptime value: anytype) OwnedRef(T) {
            return if (@TypeOf(value) == T) .{ .owned = value }
            else if (@TypeOf(value) == *const T or @TypeOf(value) == *T) .{ .borrowed = value }
            else @compileError(std.fmt.comptimePrint("{} is not of type '{1s}', '*{1s}' or '*const {1s}'", .{value, @typeName(T)}));
        }
    };
}

pub fn OwnedValue(value: anytype) OwnedRef(@TypeOf(value)) {
    return .{ .owned = value };
}

pub fn RefValue(value: anytype) OwnedRef(PtrTypeOf(@TypeOf(value))) {
    return .{ .borrowed = value };
}
