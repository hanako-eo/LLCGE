const Context = @import("../../../context.zig");
const Type = @import("../../../ir/type.zig");

child: Type,
size: usize,

const Self = @This();

pub fn init(_: *const Context, child: Type, size: usize) Self {
    return Self {
        .child = child,
        .size = size,
    }; 
}

pub fn align_of(self: Self) usize {
    return self.child.align_of();
}

pub fn size_of(self: Self) usize {
    return self.child.size_of() * self.size;
}

pub fn is_same(self: Self, other: Self) usize {
    return self.size == other.size and self.child.is_same(other.child);
}
