const std = @import("std");

const Error = @import("./error.zig").Error;

const Function = @import("./function.zig");
const Instruction = @import("./instruction.zig");
const Value = @import("./value.zig");

parent: *Function,

number: usize,
instructions: std.ArrayList(Instruction),

const Self = @This();

pub fn init(parent: *Function, number: usize) Self {
    return Self{
        .parent = parent,

        .number = number,
        .instructions = std.ArrayList(Instruction).init(parent.module.allocator),
    };
}

pub fn deinit(self: Self) void {
    self.instructions.deinit();
}

pub fn add_instruction(self: *Self, instruction: anytype) Error!*Instruction {
    const InstructionPtr = @TypeOf(instruction);
    if (@typeInfo(InstructionPtr) != .Pointer)
        @compileError(std.fmt.comptimePrint("'{}' need to be a pointer", @typeName(InstructionPtr)));

    const T = @typeInfo(InstructionPtr).Pointer.child;

    if (std.meta.hasMethod(@TypeOf(instruction), "assert"))
        instruction.assert(self.parent);

    try self.instructions.append(try Instruction.init(T, self, self.parent.index, @constCast(instruction)));
    self.parent.index += 1;

    return &self.instructions.items[self.instructions.items.len - 1];
}

pub fn get_result(self: *Self) Value {
    return Value.block(self);
}
