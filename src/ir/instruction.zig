const Value = @import("./value.zig").Value;

pub const Instruction = union(enum) {
    ret: Value,
};
