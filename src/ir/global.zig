const Type = @import("./types.zig").Type;

const Module = @import("./module.zig");
const Value = @import("./value.zig").Value;

module: *Module,

is_constant: bool,
value: Value,

const Self = @This();

pub fn init(module: *Module, is_constant: bool, value: Value) Self {
    return Self{
        .module = module,
        .is_constant = is_constant,
        .value = value,
    };
}
