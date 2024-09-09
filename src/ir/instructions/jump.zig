const std = @import("std");
const FileWriter = std.fs.File.Writer;

const Formater = @import("../writers/ir_file.zig").Formater;
const Instruction = @import("../instruction.zig");
const Type = @import("../types.zig").Type;
const Value = @import("../value.zig").Value;

const Self = @This();

label: Value,

pub fn init(label: Value) Self {
    std.debug.assert(label.type == .label);

    return Self{ .label = label };
}

pub fn getReturnValue(_: Self, _: *Instruction) Value {
    return Value.Void;
}

pub fn irFileCodegen(self: *Self, writer: *const FileWriter) std.posix.WriteError!void {
    try writer.print("jump {}", .{Formater(Value).wrap(self.label)});
}
