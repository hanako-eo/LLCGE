const std = @import("std");

const Error = @import("./error.zig").Error;

const Function = @import("./function.zig");
const Instruction = @import("./instruction.zig");
const OpCode = @import("./op_code.zig").OpCode;
const Value = @import("./value.zig").Value;

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
    if (op_code == .ret)
        std.debug.assert(op_code.ret.value.type.eq(self.parent.return_type));

    try self.instructions.append(Instruction{ .parent = self, .number = self.parent.index, .op_code = op_code });
    self.parent.index += 1;

    return &self.instructions.items[self.instructions.items.len - 1];
}

pub fn getReturnValue(self: *Self) Value {
    return Value.block(self);
}
