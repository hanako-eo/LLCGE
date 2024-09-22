const std = @import("std");
const meta_zig = @import("./meta.zig");
const get_return_type = meta_zig.get_return_type;
const PtrTypeOf = meta_zig.PtrTypeOf;

pub fn OwnedRef(comptime T: type) type {
    return union(enum) {
        owned: T,
        borrowed: *const T,

        const Self = @This();

        pub fn from_any(comptime value: anytype) OwnedRef(T) {
            return if (@TypeOf(value) == T) .{ .owned = @as(T, value) } else if (@TypeOf(value) == *const T or @TypeOf(value) == *T) .{ .borrowed = @as(*const T, value) } else @compileError(std.fmt.comptimePrint("'{s}' is not of type '{1s}', '*{1s}' or '*const {1s}'", .{ @typeName(@TypeOf(value)), @typeName(T) }));
        }
    };
}

pub fn OwnedValue(value: anytype) OwnedRef(@TypeOf(value)) {
    return .{ .owned = value };
}

pub fn RefValue(value: anytype) OwnedRef(PtrTypeOf(@TypeOf(value))) {
    return .{ .borrowed = value };
}
