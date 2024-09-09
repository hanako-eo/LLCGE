const std = @import("std");
const FileWriter = std.fs.File.Writer;

const Formater = @import("../writers/ir_file.zig").Formater;
const Instruction = @import("../instruction.zig");
const Type = @import("../types.zig").Type;
const Value = @import("../value.zig").Value;

const Self = @This();

condition: Value,
if_label: Value,
else_label: Value,

pub fn init(condition: Value, if_label: Value, else_label: Value) Self {
    std.debug.assert(condition.type == .int and condition.type.int.bits == 1);
    std.debug.assert(if_label.type == .label);
    std.debug.assert(else_label.type == .label);

    return Self{ .condition = condition, .if_label = if_label, .else_label = else_label };
}

pub fn getReturnValue(_: Self, _: *Instruction) Value {
    return Value.Void;
}

pub fn irFileCodegen(self: *Self, writer: *const FileWriter) std.posix.WriteError!void {
    try writer.print("jumpc {}, {}, {}", .{Formater(Value).wrap(self.condition), Formater(Value).wrap(self.if_label), Formater(Value).wrap(self.else_label)});
}
