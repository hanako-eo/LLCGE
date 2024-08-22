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

index: usize,
return_type: Type,
args: std.ArrayList(Argument),
blocks: std.ArrayList(Block),

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
    try self.args.append(Argument{ .number = self.index, .parent = self, .type = @"type" });
    self.index += 1;

    return &self.args.items[self.args.items.len - 1];
}

pub fn createBlock(self: *Self) Error!*Block {
    try self.blocks.append(Block.init(self.module, self.index));
    self.index += 1;

    return &self.blocks.items[self.blocks.items.len - 1];
}
