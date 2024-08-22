const std = @import("std");

const Type = @import("./types.zig").Type;
const FunctionArgument = @import("./function.zig").Argument;
const Global = @import("./global.zig");
const Instruction = @import("./instruction.zig").Instruction;

pub const Constant = union(enum) {
    int: isize,
    uint: usize,
    array: []const Constant,

    null_ptr: void,
    zero_initializer: void,

    const Self = @This();

    pub fn format(
        self: Self,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        switch (self) {
            .int => |int| try writer.print("{}", .{int}),
            .uint => |int| try writer.print("{}", .{int}),
            .array => |array| {
                try writer.writeByte('[');
                if (array.len > 0) {
                    for (array[0 .. array.len - 1]) |constant| {
                        try writer.print("{}, ", .{constant});
                    }
                    try writer.print("{}", .{array[array.len - 1]});
                }
                try writer.writeByte(']');
            },
            .null_ptr => try writer.writeAll("null"),
            .zero_initializer => try writer.writeAll("zero_initializer"),
        }
    }
};

pub const Ref = union(enum) {
    argument: *FunctionArgument,
    global: *Global,
    instruction: *Instruction,
};

pub const Value = struct {
    type: Type,
    value: union(enum) {
        constant: Constant,
        ref: Ref,
    },

    const Self = @This();
    pub const Void = Self{
        .type = .void,
        .value = .{ .constant = .zero_initializer },
    };

    pub fn argument(@"type": Type, argument_ptr: *FunctionArgument) Self {
        return Self{
            .type = @"type",
            .value = .{ .ref = .{ .argument = argument_ptr } },
        };
    }

    pub fn global(@"type": Type, global_ptr: *Global) Self {
        return Self{
            .type = @"type",
            .value = .{ .ref = .{ .global = global_ptr } },
        };
    }

    pub fn instruction(@"type": Type, instruction_ptr: *Instruction) Self {
        return Self{
            .type = @"type",
            .value = .{ .ref = .{ .instruction = instruction_ptr } },
        };
    }

    pub fn format(
        self: Self,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.print("{} ", .{self.type});
        try switch (self.value) {
            .constant => |c| writer.print("{}", .{c}),
            .ref => |r| switch (r) {
                inline .argument, .instruction => |inst| writer.print("%{}", .{inst.number}),
                .global => |glob| writer.print("@{s}", .{glob.name}),
            },
        };
    }
};
