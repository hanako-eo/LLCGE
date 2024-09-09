const std = @import("std");
const Allocator = std.mem.Allocator;

const Error = @import("./error.zig").Error;

const Type = @import("./types.zig").Type;
const FunctionType = @import("./types/function.zig");

const Constant = @import("./value.zig").Constant;
const Function = @import("./function.zig");
const Global = @import("./global.zig");

allocator: Allocator,
source: ?[]const u8,

globals: std.StringHashMap(Global),
functions: std.StringHashMap(Function),

const Self = @This();

pub fn init(allocator: Allocator) Self {
    return Self{
        .allocator = allocator,
        .source = null,
        .globals = std.StringHashMap(Global).init(allocator),
        .functions = std.StringHashMap(Function).init(allocator),
    };
}

pub fn initFromSource(allocator: Allocator, source: []const u8) Self {
    return Self{
        .allocator = allocator,
        .source = source,
        .globals = std.StringHashMap(Global).init(allocator),
        .functions = std.StringHashMap(Function).init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    var it = self.functions.valueIterator();
    while (it.next()) |function| {
        function.deinit();
    }
    self.functions.deinit();
    self.globals.deinit();
}

pub fn createGlobal(self: *Self, name: []const u8, is_constant: bool, @"type": Type, value: Constant) Error!*Global {
    if (self.globals.contains(name))
        return Error.AlreadyDefine;

    const entry = try self.globals.getOrPutValue(name, Global.init(self, name, is_constant, @"type", value));
    return entry.value_ptr;
}

pub fn createFunction(self: *Self, name: []const u8, return_type: Type) Error!*Function {
    if (self.functions.contains(name))
        return Error.AlreadyDefine;

    const entry = try self.functions.getOrPutValue(name, Function.init(self, return_type));
    return entry.value_ptr;
}
