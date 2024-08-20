const Type = @import("./types.zig").Type;
const FunctionArgument = @import("./function.zig").Argument;
const Global = @import("./global.zig");
const Instruction = @import("./instruction.zig");

pub const Constant = union(enum) {
    int: isize,
    uint: usize,
    array: []const Constant,

    null_ptr: void,
    zero_initializer: void,
};

pub const Ref = union(enum) {
    argument: *FunctionArgument,
    global: *Global,
    instruction: *Instruction,
};

pub const Value = struct {
    type: Type,
    value: union(enum) {
        constant: Constant,
        ref: Ref,
    },

    const Self = @This();
    pub const Void = Self{
        .type = .void,
        .value = .{ .constant = .zero_initializer },
    };

    pub fn fromInstruction(@"type": Type, instruction: *Instruction) Self {
        return Self{
            .type = @"type",
            .value = .{ .ref = .{ .instruction = instruction } },
        };
    }
};
