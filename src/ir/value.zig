const Type = @import("./types.zig").Type;
const FunctionArgument = @import("./function.zig").Argument;
const Global = @import("./global.zig");
const Instruction = @import("./instruction.zig");

pub const Constant = union(enum) {
    int: isize,
    uint: usize,
    array: []const Constant,

    zero_initializer: void,
};

pub const Value = struct {
    type: Type,
    value: Constant,
};

pub const Ref = struct {
    type: Type,
    ref: union(enum) {
        argument: *FunctionArgument,
        global: *Global,
        instruction: *Instruction,
    },
};
