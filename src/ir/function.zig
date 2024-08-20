const std = @import("std");

const Error = @import("./error.zig").Error;

const Module = @import("./module.zig");
const Type = @import("./types.zig").Type;
const Block = @import("./block.zig");

pub const Argument = struct {
    number: usize,
    parent: *Self,
    type: Type,
};

module: *Module,

return_type: Type,
args: std.ArrayList(Argument),
blocks: std.StringHashMap(Block),

const Self = @This();

pub fn init(module: *Module, return_type: Type) Self {
    return Self{
        .module = module,

        .return_type = return_type,
        .args = std.ArrayList(Argument).init(module.allocator),
        .blocks = std.StringHashMap(Block).init(module.allocator),
    };
}

pub fn addArgument(self: *Self, @"type": Type) Error!*Argument {
    const index = self.args.items.len;
    try self.args.append(Argument{ .number = index, .parent = self, .type = @"type" });

    return &self.args.items[index];
}

pub fn createBlock(self: *Self) Error!*Block {
    const index = self.blocks.items.len;
    try self.blocks.append(Block.init(self.module, index));

    return &self.blocks.items[index];
}
