const std = @import("std");

const Instruction = @import("../instruction.zig");
const OpCode = @import("../op_code.zig").OpCode;
const Type = @import("../types.zig").Type;
const Value = @import("../value.zig").Value;

const Self = @This();

result_type: Type,
base: Value,

pub fn init(result_type: Type, base: Value) OpCode {
    std.debug.assert(base.type.castable(result_type));

    return .{ .cast = .{ .result_type = result_type, .base = base } };
}

pub fn getReturnValue(self: Self, instruction: *Instruction) Value {
    return Value.instruction(self.result_type, instruction);
}
