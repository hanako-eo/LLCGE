const std = @import("std");

const Instruction = @import("../instruction.zig");
const OpCode = @import("../op_code.zig").OpCode;
const Type = @import("../types.zig").Type;
const Value = @import("../value.zig").Value;

const Self = @This();

label: Value,

pub fn init(label: Value) OpCode {
    std.debug.assert(label.type == .label);

    return .{ .jump = .{ .label = label } };
}

pub fn getReturnValue(_: Self, _: *Instruction) Value {
    return Value.Void;
}
