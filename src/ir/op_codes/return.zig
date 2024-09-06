const std = @import("std");

const Instruction = @import("../instruction.zig");
const OpCode = @import("../op_code.zig").OpCode;
const Value = @import("../value.zig").Value;

const Self = @This();

value: Value,

pub fn init(value: ?Value) Self {
    return .{ .ret = .{ .value = value orelse Value.Void } };
}

pub fn getReturnValue(_: Self, _: *Instruction) Value {
    return Value.Void;
}
