const Type = @import("../types.zig").Type;

child: Type,

const Self = @This();

pub fn sizeOf(_: Self) usize {
    return @sizeOf(*anyopaque);
}
