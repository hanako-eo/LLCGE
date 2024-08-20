const std = @import("std");
const Allocator = std.mem.Allocator;

const Error = @import("./error.zig").Error;

const Type = @import("./types.zig").Type;
const FunctionType = @import("./types/function.zig");

const Value = @import("./value.zig").Value;
const Function = @import("./function.zig");
const Global = @import("./global.zig");

source: []const u8,
allocator: Allocator,

globals: std.StringHashMap(Global),
functions: std.StringHashMap(Function),

const Self = @This();

pub fn createGlobal(self: *Self, name: []const u8, is_constant: bool, value: Value) Error!*Global {
    if (self.globals.contains(name))
        return Error.AlreadyDefine;

    const entry = try self.globals.getOrPutValue(name, Global.init(self, is_constant, value));
    return entry.value_ptr;
}

pub fn createFunction(self: *Self, name: []const u8, return_type: Type) Error!*Function {
    if (self.functions.contains(name))
        return Error.AlreadyDefine;

    const entry = try self.functions.getOrPutValue(name, Function.init(self, return_type));
    return entry.value_ptr;
}
