const Type = @import("./types.zig").Type;

const Module = @import("./module.zig");
const value_zig = @import("./value.zig");
const Constant = value_zig.Constant;
const Value = value_zig.Value;

module: *Module,

name: []const u8,
is_constant: bool,
value: Value,

const Self = @This();

pub fn init(module: *Module, name: []const u8, is_constant: bool, @"type": Type, value: Constant) Self {
    return Self{
        .module = module,
        .name = name,
        .is_constant = is_constant,
        .value = Value{ .type = @"type", .value = .{ .constant = value } },
    };
}

pub fn getValue(self: *Self) Value {
    return Value{ .type = .{ .pointer = .{ .child = &self.value.type } }, .value = .{ .ref = .{ .global = self } } };
}
