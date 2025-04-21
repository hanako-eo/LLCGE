const SSAValue = @import("../ssa_value.zig");
const Type = @import("../type.zig");

index: usize,
ty: Type,
value: SSAValue,

const Self = @This();

pub fn get_result(self: *const Self) SSAValue {
    return self.value;
}
