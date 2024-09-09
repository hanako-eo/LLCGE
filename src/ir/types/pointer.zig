const Type = @import("../types.zig").Type;

child: *const Type,

const Self = @This();

pub fn eq(self: Self, other: Self) bool {
    return self.child.eq(other.child.*);
}

pub fn sizeOf(_: Self) usize {
    return @sizeOf(*anyopaque);
}
