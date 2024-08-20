const std = @import("std");

const Module = @import("./module.zig");
// const Type = @import("./types.zig").Type;
const Instruction = @import("./instruction.zig").Instruction;

module: *Module,

number: usize,
instructions: std.ArrayList(Instruction),

const Self = @This();

pub fn init(module: *Module, number: usize) Self {
    return Self{
        .module = module,

        .number = number,
        .instructions = std.ArrayList(Instruction).init(module.allocator),
    };
}
