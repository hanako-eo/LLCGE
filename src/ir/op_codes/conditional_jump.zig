const std = @import("std");

const Instruction = @import("../instruction.zig");
const OpCode = @import("../op_code.zig").OpCode;
const Type = @import("../types.zig").Type;
const Value = @import("../value.zig").Value;

const Self = @This();

condition: Value,
if_label: Value,
else_label: Value,

pub fn init(condition: Value, if_label: Value, else_label: Value) OpCode {
    std.debug.assert(condition.type == .int and condition.type.int.bits == 1);
    std.debug.assert(if_label.type == .label);
    std.debug.assert(else_label.type == .label);

    return .{ .jumpc = .{ .condition = condition, .if_label = if_label, .else_label = else_label } };
}

pub fn getReturnValue(_: Self, _: *Instruction) Value {
    return Value.Void;
}
