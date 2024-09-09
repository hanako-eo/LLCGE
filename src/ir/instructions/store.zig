const std = @import("std");
const FileWriter = std.fs.File.Writer;

const Formater = @import("../writers/ir_file.zig").Formater;
const Instruction = @import("../instruction.zig");
const Type = @import("../types.zig").Type;
const Value = @import("../value.zig").Value;

const Self = @This();

pointer: Value,
value: Value,

pub fn init(pointer: Value, value: Value) Self {
    std.debug.assert(pointer.type == .pointer);
    std.debug.assert(pointer.type.pointer.child.* == value.type);

    return Self{ .pointer = pointer, .value = value };
}

pub fn getReturnValue(_: Self, _: *Instruction) Value {
    return Value.Void;
}

pub fn irFileCodegen(self: *Self, writer: *const FileWriter) std.posix.WriteError!void {
    try writer.print("store {}, {}", .{ Formater(Value).wrap(self.value), Formater(Value).wrap(self.pointer) });
}
