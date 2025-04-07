const std = @import("std");
const meta = @import("../meta.zig");
const Allocator = std.mem.Allocator;

pub const Alignment = enum(u64) {
    @"0" = 1 << 0,
    @"1" = 1 << 1,
    @"2" = 1 << 2,
    @"3" = 1 << 3,
    @"4" = 1 << 4,
    @"5" = 1 << 5,
    @"6" = 1 << 6,
    @"7" = 1 << 7,
    @"8" = 1 << 8,
    @"9" = 1 << 9,
    @"10" = 1 << 10,
    @"11" = 1 << 11,
    @"12" = 1 << 12,
    @"13" = 1 << 13,
    @"14" = 1 << 14,
    @"15" = 1 << 15,
    @"16" = 1 << 16,
    @"17" = 1 << 17,
    @"18" = 1 << 18,
    @"19" = 1 << 19,
    @"20" = 1 << 20,
    @"21" = 1 << 21,
    @"22" = 1 << 22,
    @"23" = 1 << 23,
    @"24" = 1 << 24,
    @"25" = 1 << 25,
    @"26" = 1 << 26,
    @"27" = 1 << 27,
    @"28" = 1 << 28,
    @"29" = 1 << 29,
    @"30" = 1 << 30,
    @"31" = 1 << 31,
    @"32" = 1 << 32,
    @"33" = 1 << 33,
    @"34" = 1 << 34,
    @"35" = 1 << 35,
    @"36" = 1 << 36,
    @"37" = 1 << 37,
    @"38" = 1 << 38,
    @"39" = 1 << 39,
    @"40" = 1 << 40,
    @"41" = 1 << 41,
    @"42" = 1 << 42,
    @"43" = 1 << 43,
    @"44" = 1 << 44,
    @"45" = 1 << 45,
    @"46" = 1 << 46,
    @"47" = 1 << 47,
    @"48" = 1 << 48,
    @"49" = 1 << 49,
    @"50" = 1 << 50,
    @"51" = 1 << 51,
    @"52" = 1 << 52,
    @"53" = 1 << 53,
    @"54" = 1 << 54,
    @"55" = 1 << 55,
    @"56" = 1 << 56,
    @"57" = 1 << 57,
    @"58" = 1 << 58,
    @"59" = 1 << 59,
    @"60" = 1 << 60,
    @"61" = 1 << 61,
    @"62" = 1 << 62,
    @"63" = 1 << 63,
};

/// Internal type the type used to help to downcast the ptr.
ty: type,
/// Allocator used to store the ptr, if the allocator is set to null, it means
/// the ptr point to a static pointer or managed by the user it-self.
allocator: ?Allocator,

/// Pointer to the real data that contain all useful data of the type.
ptr: *const anyopaque,
vtable: *const VTable,

const Self = @This();
const VTable = struct {
    align_of: *const fn (self: *const anyopaque) Alignment,
    size_of: *const fn (self: *const anyopaque) usize,

    is_same: *const fn (self: *const anyopaque, other: *const anyopaque) bool,
    deinit: ?*const fn (self: *const anyopaque) void,
};

pub fn init(comptime T: type, args: std.meta.ArgsTuple(@TypeOf(T.init)), allocator: Allocator) anyerror!Self {
    const ptr = try allocator.create(T);
    const init_type = @typeInfo(@TypeOf(T.init)).@"fn";
    if (@typeInfo(init_type.return_type.?) == .error_union) {
        ptr.* = try @call(.auto, T.init, args);
    } else {
        ptr.* = @call(.auto, T.init, args);
    }

    return Self {
        .ty = T,
        .ptr = ptr,
        .allocator = allocator,
        .vtable = &.{
            .align_of = meta.vtable_method(T, &T.align_of),
            .size_of = meta.vtable_method(T, &T.size_of),
            .is_same = meta.vtable_method(T, &T.is_same),
            .deinit = if (@hasDecl(T, "deinit")) meta.vtable_method(T, &T.deinit) else null,
        },
    };
}

pub fn static_init(comptime T: type, ptr: *const T) Self {
    return Self {
        .ty = T,
        .ptr = ptr,
        .allocator = null,
        .vtable = &.{
            .align_of = meta.vtable_method(T, &T.align_of),
            .size_of = meta.vtable_method(T, &T.size_of),
            .is_same = meta.vtable_method(T, &T.is_same),
            .deinit = if (@hasDecl(T, "deinit")) meta.vtable_method(T, &T.deinit) else null,
        },
    };
}

pub fn deinit(self: Self) void {
    if (self.vtable.deinit) |vt_deinit| {
        vt_deinit(self.ptr);
    }
    if (self.allocator) |allocator| {
        allocator.destroy(self.ptr);
    }
}

pub fn align_of(self: Self) Alignment {
    return self.vtable.align_of(self.ptr);
}

pub fn size_of(self: Self) usize {
    return self.vtable.size_of(self.ptr);
}

pub fn is_same(self: Self, other: Self) usize {
    // this mean that the given type not base on the same type like doing
    // `i8.is_same(ptr)`
    if (self.ty != other.ty)
        return false;

    // is_same can be called safely because we ensure that *anyopaque is a ptr
    // to the same type 
    return self.vtable.is_same(self.ptr, other.ptr);
}

pub fn try_downcast(self: Self, comptime T: type) ?*const T {
    if (self.ty == T)
        return @as(*const T, self.ptr);
    
    return null;
}
