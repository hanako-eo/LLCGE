const std = @import("std");

const Error = @import("./error.zig").Error;

const Function = @import("./function.zig");
const instruction_zig = @import("./instruction.zig");
const Instruction = instruction_zig.Instruction;
const OpCode = instruction_zig.OpCode;

parent: *Function,

number: usize,
instructions: std.ArrayList(Instruction),

const Self = @This();

pub fn init(parent: *Function, number: usize) Self {
    return Self{
        .parent = parent,

        .number = number,
        .instructions = std.ArrayList(Instruction).init(parent.module.allocator),
    };
}

pub fn addInstruction(self: *Self, op_code: OpCode) Error!*Instruction {
    const index = self.instructions.items.len;
    try self.instructions.append(Instruction{ .parent = self, .number = index, .op_code = op_code });

    return &self.instructions.items[index];
}
