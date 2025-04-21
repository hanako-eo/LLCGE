const std = @import("std");
const utils = @import("utils");

const Context = @import("../context.zig");
const Instruction = @import("./instruction.zig");
const Type = @import("./type.zig");
const SSAValue = @import("./ssa_value.zig");

pub const Argument = @import("./block/argument.zig");
pub const Builder = @import("./block/builder.zig");

parent_type_id: utils.TypeId,
parent_ptr: *anyopaque,

context: *const Context,
args: []const Argument,
instructions: std.ArrayList(Instruction),

const Self = @This();

pub fn new(self: *Self, comptime T: type, parent: *T, inputs: []const Type, context: *const Context) !void {
    self.* = Self{
        .parent_type_id = utils.meta.typeId(T),
        .parent_ptr = @ptrCast(parent),

        .context = context,
        .args = undefined,
        .instructions = std.ArrayList(Instruction).init(context.allocator),
    };

    var args = try context.allocator.alloc(Argument, inputs.len);
    for (inputs, 0..) |ty, i| {
        args[i] = Argument{
            .ty = ty,
            .value = undefined,
        };
        args[i].value = SSAValue.init(Argument, &args[i], ty, i, context.allocator);
    }
    self.ptr.args = args;
}

pub fn deinit(self: Self) void {
    for (self.instructions.items) |instr| {
        instr.deinit();
    }
    self.instructions.deinit();
}

pub fn builder(self: *Self) Builder {
    return Builder {
        .block = self,
    };
}
