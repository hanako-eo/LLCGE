const ArrayType = @import("./types/array.zig");
const PointerType = @import("./types/pointer.zig");
const IntType = @import("./types/int.zig");

pub const Type = union(enum) {
    array: ArrayType,
    pointer: PointerType,
    int: IntType,
    void: void,

    const Self = @This();

    pub fn sizeOf(self: Self) usize {
        switch (self) {
            inline else => |t| t.sizeOf(),
        }
    }
};
