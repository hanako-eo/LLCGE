const std = @import("std");
const FileWriter = std.fs.File.Writer;

const Formater = @import("../writers/ir_file.zig").Formater;
const Instruction = @import("../instruction.zig");
const Type = @import("../types.zig").Type;
const Value = @import("../value.zig").Value;

const Self = @This();

element: Type,
pointer: Value,

pub fn init(element: Type, pointer: Value) Self {
    std.debug.assert(pointer.type == .pointer);
    std.debug.assert(pointer.type.pointer.child.eq(element));

    return Self{ .element = element, .pointer = pointer };
}

pub fn getReturnValue(self: Self, instruction: *Instruction) Value {
    return Value.instruction(self.element, instruction);
}

pub fn irFileCodegen(self: *Self, writer: *const FileWriter) std.posix.WriteError!void {
    try writer.print("load {}, {}", .{ Formater(Type).wrap(self.element), Formater(Value).wrap(self.pointer) });
}
