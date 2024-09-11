const Type = @import("../types.zig").Type;

child: *Type,
size: usize,

const Self = @This();

pub fn eq(self: Self, other: Self) bool {
    return self.size == other.size and self.child.eq(other.child.*);
}

pub fn size_of(self: Self) usize {
    return self.child.size_of() * self.size;
}
