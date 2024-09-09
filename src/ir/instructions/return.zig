const std = @import("std");
const FileWriter = std.fs.File.Writer;

const Formater = @import("../writers/ir_file.zig").Formater;
const Instruction = @import("../instruction.zig");
const Function = @import("../function.zig");
const Type = @import("../types.zig").Type;
const Value = @import("../value.zig").Value;

const Self = @This();

value: Value,

pub fn init(value: ?Value) Self {
    return Self{ .value = value orelse Value.Void };
}

pub fn assert(self: Self, function: *Function) void {
    std.debug.assert(self.value.type.eq(function.return_type));
}

pub fn getReturnValue(_: *Self, _: *Instruction) Value {
    return Value.Void;
}

pub fn irFileCodegen(self: *Self, writer: *const FileWriter) std.posix.WriteError!void {
    try if (self.value.type == .void) writer.writeAll("ret void")
    else writer.print("ret {}", .{Formater(Value).wrap(self.value)});
}
