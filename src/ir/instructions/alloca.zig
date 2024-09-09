const std = @import("std");
const FileWriter = std.fs.File.Writer;

const Formater = @import("../writers/ir_file.zig").Formater;
const Instruction = @import("../instruction.zig");
const Type = @import("../types.zig").Type;
const Value = @import("../value.zig").Value;

const Self = @This();

value: Value,

pub fn init(@"type": Type, size: usize) Self {
    std.debug.assert(size > 0);

    return Self{ .type = @"type", .size = size };
}

pub fn getReturnValue(self: Self, instruction: *Instruction) Value {
    return Value.instruction(self.type, instruction);
}

pub fn irFileCodegen(self: *Self, writer: *const FileWriter) std.posix.WriteError!void {
    try writer.print("alloca {}", .{Formater(Type).wrap(self.type)});
}
