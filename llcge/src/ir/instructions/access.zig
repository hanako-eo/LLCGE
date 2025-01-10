const std = @import("std");
const FileWriter = std.fs.File.Writer;

const Formater = @import("../writers/ir_file.zig").Formater;
const Instruction = @import("../instruction.zig");
const Type = @import("../types.zig").Type;
const Value = @import("../value.zig").Value;

const Self = @This();

pointer: Value,
indexes: []const Value,

pub fn init(pointer: Value, indexes: []const Value) Self {
    std.debug.assert(pointer.type == .array or pointer.type == .pointer);
    for (indexes) |index|
        std.debug.assert(index.type == .int);

    return Self{ .pointer = pointer, .indexes = indexes };
}

pub fn get_result(self: Self, instruction: *Instruction) Value {
    return Value.instruction(get_ptr_child(self.pointer.type).*, instruction);
}

pub fn ir_file_codegen(self: *Self, writer: *const FileWriter) std.posix.WriteError!void {
    try writer.print("access {}", .{Formater(Value).wrap(self.pointer)});
    for (self.indexes) |index|
        try writer.print(", {}", .{Formater(Value).wrap(index)});
}

fn get_ptr_child(t: Type) *Type {
    return switch (t) {
        inline .array, .pointer => |ptr| ptr.child,
        else => unreachable,
    };
}
