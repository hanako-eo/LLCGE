const std = @import("std");

const Instruction = @import("../instruction.zig");
const OpCode = @import("../op_code.zig").OpCode;
const Type = @import("../types.zig").Type;
const Value = @import("../value.zig").Value;

const Self = @This();

pointer: Value,
indexes: []const Value,

pub fn init(pointer: Value, indexes: []const Value) OpCode {
    std.debug.assert(pointer.type == .array or pointer.type == .pointer);
    for (indexes) |index|
        std.debug.assert(index.type == .int);

    return .{ .access_ptr = .{ .pointer = pointer, .indexes = indexes } };
}

pub fn getReturnValue(self: Self, instruction: *Instruction) Value {
    return Value.instruction(.{ .pointer = .{ .child = getPtrChild(self.pointer.type) } }, instruction);
}

fn getPtrChild(t: Type) *Type {
    return switch (t) {
        inline .array, .pointer => |ptr| ptr.child,
        else => unreachable,
    };
}
