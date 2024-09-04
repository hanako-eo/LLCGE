const std = @import("std");

const Instruction = @import("../instruction.zig");
const OpCode = @import("../op_code.zig").OpCode;
const Type = @import("../types.zig").Type;
const Value = @import("../value.zig").Value;

const Self = @This();

element: Type,
pointer: Value,

pub fn init(element: Type, pointer: Value) OpCode {
    std.debug.assert(pointer.type == .pointer);
    std.debug.assert(pointer.type.pointer.child.eq(element));

    return .{ .load = .{ .element = element, .pointer = pointer } };
}

pub fn getReturnValue(self: Self, instruction: *Instruction) Value {
    return Value.instruction(self.element, instruction);
}
