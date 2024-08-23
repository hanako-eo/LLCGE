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
        _ = options;

        switch (self) {
            inline .int, .uint => |int| {
                if (std.mem.eql(u8, fmt, "c"))
                    try writer.print("{c}", .{@as(u8, @truncate(@as(usize, @bitCast(int))))})
                else
                    try writer.print("{d}", .{int});
            },
            .array => |array| {
                if (std.mem.eql(u8, fmt, "s")) {
                    try writer.writeByte('"');
                    for (array) |char| {
                        try writer.print("{c}", .{char});
                    }
                    try writer.writeByte('"');
                }
                try writer.writeByte('[');
                for (array, 0..) |constant, i| {
                    try if (i == 0)
                        writer.print("{}", .{constant})
                    else
                        writer.print(", {}", .{constant});
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

    fn isString(t: Type) bool {
        return (t == .array or t == .pointer) and switch (t) {
            inline .array, .pointer => |ptr| ptr.child.* == .int and ptr.child.int.bits == 8,
            else => unreachable,
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
            .constant => |c| if (isString(self.type)) writer.print("{s}", .{c}) else writer.print("{}", .{c}),
            .ref => |r| switch (r) {
                inline .argument, .instruction => |inst| writer.print("%{}", .{inst.number}),
                .global => |glob| writer.print("@{s}", .{glob.name}),
            },
        };
    }
};
