const std = @import("std");

const Type = @import("./types.zig").Type;
const FunctionArgument = @import("./function.zig").Argument;
const Block = @import("./block.zig");
const Global = @import("./global.zig");
const Instruction = @import("./instruction.zig");

pub const Constant = union(enum) {
    int: isize,
    uint: usize,
    array: []const Constant,

    null_ptr: void,
    zero_initializer: void,

    const Self = @This();
};

pub const Ref = union(enum) {
    argument: *FunctionArgument,
    block: *Block,
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

    pub fn argument(@"type": Type, argument_ptr: *FunctionArgument) Self {
        return Self{
            .type = @"type",
            .value = .{ .ref = .{ .argument = argument_ptr } },
        };
    }

    pub fn block(block_ptr: *Block) Self {
        return Self{
            .type = .label,
            .value = .{ .ref = .{ .block = block_ptr } },
        };
    }

    pub fn global(@"type": Type, global_ptr: *Global) Self {
        return Self{
            .type = @"type",
            .value = .{ .ref = .{ .global = global_ptr } },
        };
    }

    pub fn instruction(@"type": Type, instruction_ptr: *Instruction) Self {
        return Self{
            .type = @"type",
            .value = .{ .ref = .{ .instruction = instruction_ptr } },
        };
    }
};
