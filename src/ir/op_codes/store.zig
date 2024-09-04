const std = @import("std");

const Instruction = @import("../instruction.zig");
const OpCode = @import("../op_code.zig").OpCode;
const Type = @import("../types.zig").Type;
const Value = @import("../value.zig").Value;

const Self = @This();

pointer: Value,
value: Value,

pub fn init(pointer: Value, value: Value) OpCode {
    std.debug.assert(pointer.type == .pointer);
    std.debug.assert(pointer.type.pointer.child.* == value.type);

    return .{ .store = .{ .pointer = pointer, .value = value } };
}

pub fn getReturnValue(_: Self, _: *Instruction) Value {
    return Value.Void;
}
