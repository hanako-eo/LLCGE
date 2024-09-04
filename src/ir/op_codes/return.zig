const std = @import("std");

const Instruction = @import("../instruction.zig");
const OpCode = @import("../op_code.zig").OpCode;
const Type = @import("../types.zig").Type;
const Value = @import("../value.zig").Value;

const Self = @This();

type: Type,
size: usize,

pub fn init(@"type": Type, size: usize) OpCode {
    std.debug.assert(size > 0);
    return .{ .alloca = .{ .type = @"type", .size = size } };
}

pub fn getReturnValue(_: Self, _: *Instruction) Value {
    return Value.Void;
}
