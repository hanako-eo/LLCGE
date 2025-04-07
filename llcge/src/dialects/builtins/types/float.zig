const std = @import("std");
const Type = @import("../../../ir/type.zig");

size: u16,

const Self = @This();

pub const F16 = Type.static_init(Self, &Self { .size = 16 });
pub const F32 = Type.static_init(Self, &Self { .size = 32 });
pub const F64 = Type.static_init(Self, &Self { .size = 64 });
// TODO: maybe later ?
// pub const F80 = Type.static_init(Self, &Self { .size = 80 });
pub const F128 = Type.static_init(Self, &Self { .size = 128 });

/// Return the alignement of an int (it's the same as the size)
pub fn align_of(self: Self) usize {
    return self.size_of();
}

pub fn size_of(self: Self) usize {
    return self.size / 8;
}

pub fn is_same(self: Self, other: Self) usize {
    return self.size == other.size;
}