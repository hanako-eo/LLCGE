const std = @import("std");
const FileWriter = std.fs.File.Writer;

const Formater = @import("../writers/ir_file.zig").Formater;
const Instruction = @import("../instruction.zig");
const Type = @import("../types.zig").Type;
const Value = @import("../value.zig").Value;

const Self = @This();

result_type: Type,
base: Value,

pub fn init(result_type: Type, base: Value) Self {
    std.debug.assert(base.type.castable(result_type));

    return Self{ .result_type = result_type, .base = base };
}

pub fn getReturnValue(self: Self, instruction: *Instruction) Value {
    return Value.instruction(self.result_type, instruction);
}

pub fn irFileCodegen(self: *Self, writer: *const FileWriter) std.posix.WriteError!void {
    try writer.print("cast {}, {}", .{ Formater(Type).wrap(self.result_type), Formater(Value).wrap(self.base) });
}
