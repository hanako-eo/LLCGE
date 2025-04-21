const std = @import("std");
const Allocator = std.mem.Allocator;
const utils = @import("utils");


const Block = @import("./block.zig");
const Context = @import("../context.zig");

context: *const Context,
source: ?[]const u8,

body: Block,

const Self = @This();

pub fn init(source: ?[]const u8, context: *const Context) !utils.mem.Bin(Self) {
    var self = try utils.mem.Bin(Self).init(Self{
        .context = context,
        .source = source,
        .body = undefined,
    }, context.allocator);
    
    try self.ptr.body.new(Self, self, &.{}, context);

    return self;
}

pub fn deinit(self: *Self) void {
    self.body.deinit();
}

pub fn builder(self: *Self) Block.Builder {
    return self.body.builder();
}
