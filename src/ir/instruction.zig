const std = @import("std");
const FileWriter = std.fs.File.Writer;

const Block = @import("./block.zig");
const Value = @import("./value.zig").Value;

// Memory Access and Addressing Operands
pub const Alloca = @import("./instructions/alloca.zig");
pub const Load = @import("./instructions/load.zig");
pub const Store = @import("./instructions/store.zig");
pub const AccessPtr = @import("./instructions/access_ptr.zig");
pub const Access = @import("./instructions/access.zig");

// Type Operations
pub const Cast = @import("./instructions/cast.zig");

// Control Flow Operands
pub const Jump = @import("./instructions/jump.zig");
pub const ConditionalJump = @import("./instructions/conditional_jump.zig");
pub const Return = @import("./instructions/return.zig");

parent: *Block,
number: usize,

inner: *anyopaque,
vtable: VTable,

const Self = @This();
const VTable = struct {
    get_result: *const fn (self: *anyopaque, instruction: *const Self) Value,
    ir_file_codegen: *const fn (self: *anyopaque, writer: *const FileWriter) std.posix.WriteError!void,
};

pub fn init(comptime T: type, parent: *Block, number: usize, instruction: *T) !Self {
    return Self{ .parent = parent, .number = number, .inner = instruction, .vtable = VTable{
        .get_result = @ptrCast(&T.get_result),
        .ir_file_codegen = @ptrCast(&T.ir_file_codegen),
    } };
}

pub inline fn get_result(self: Self) Value {
    return self.vtable.get_result(self.inner, &self);
}
