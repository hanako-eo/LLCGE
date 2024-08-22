const Type = @import("../types.zig").Type;

child: *Type,
size: usize,

const Self = @This();

pub fn sizeOf(self: Self) usize {
    return self.child.sizeOf() * self.size;
}
