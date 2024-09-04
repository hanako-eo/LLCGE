const std = @import("std");

const Block = @import("./block.zig");
const OpCode = @import("./op_code.zig").OpCode;
const Value = @import("./value.zig").Value;

parent: *Block,
number: usize,
op_code: OpCode,

const Self = @This();

pub inline fn getReturnValue(self: *Self) Value {
    return self.op_code.getReturnValue(self);
}
