const std = @import("std");
const Allocator = std.mem.Allocator;
const File = std.fs.File;

const Function = @import("../function.zig");
const Global = @import("../global.zig");
const Instruction = @import("../instruction.zig");
const Module = @import("../module.zig");
const Type = @import("../types.zig").Type;
const value_zig = @import("../value.zig");
const Constant = value_zig.Constant;
const Value = value_zig.Value;

file: File,
writer: File.Writer,

const Self = @This();

pub fn init(path: []const u8) !Self {
    const file = try std.fs.cwd().createFile(path, .{
        .truncate = true,
        .exclusive = false,
        .lock = .exclusive,
    });

    return Self{
        .file = file,
        .writer = file.writer(),
    };
}

pub fn deinit(self: Self) void {
    self.file.close();
}

pub fn codegen(self: Self, module: *Module) !void {
    if (module.source) |source|
        try self.writer.print("module_source \"{s}\"\n", .{source});

    // Add section space to separate IR info and globals
    if ((self.file.getPos() catch 0) != 0)
        try self.writer.writeByte('\n');

    var globals_iterator = module.globals.iterator();
    while (globals_iterator.next()) |entry|
        try self.codegen_global(entry.key_ptr.*, entry.value_ptr);

    // Add section space to separate globals and functions
    if (module.globals.count() != 0)
        try self.writer.writeByte('\n');

    var functions_iterator = module.functions.iterator();
    while (functions_iterator.next()) |entry|
        try self.codegen_function(entry.key_ptr.*, entry.value_ptr);
}

pub fn codegen_global(self: Self, name: []const u8, global: *const Global) !void {
    try self.writer.print("define {s} {}* @{s} = {}\n", .{ if (global.is_constant) "local const" else "global", Formater(Type).wrap(global.value.type), name, Formater(Value).wrap(global.value) });
}

pub fn codegen_function(self: Self, name: []const u8, function: *const Function) !void {
    try self.writer.print("define local {} @{s}(", .{ Formater(Type).wrap(function.return_type), name });
    for (function.args.items, 0..) |arg, i| {
        try if (i == 0)
            self.writer.print("{} %{}", .{ Formater(Type).wrap(arg.type), arg.number })
        else
            self.writer.print(", {} %{}", .{ Formater(Type).wrap(arg.type), arg.number });
    }
    try self.writer.writeAll(") {\n");
    for (function.blocks.items, 0..) |block, i| {
        if (i != 0) try self.writer.writeByte('\n');

        try self.writer.print("%{}:\n", .{block.number});
        for (block.instructions.items) |instruction| {
            try self.writer.writeByte('\t');
            try self.codegen_instruction(&instruction);
        }
    }
    try self.writer.writeAll("}\n");
}

pub fn codegen_instruction(self: Self, instruction: *const Instruction) !void {
    try self.writer.print("%{} = ", .{instruction.number});
    try instruction.vtable.ir_file_codegen(instruction.inner, &self.writer);
    try self.writer.writeByte('\n');
}

// FORMATER
pub fn Formater(comptime T: type) type {
    return struct {
        inner: T,

        pub fn wrap(inner: T) @This() {
            return @This(){ .inner = inner };
        }

        pub fn format(
            self: @This(),
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = options;

            switch (T) {
                Constant => {
                    switch (self.inner) {
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
                                    try writer.print("{c}", .{Formater(Constant).wrap(char)});
                                }
                                try writer.writeByte('"');
                            } else {
                                try writer.writeByte('[');
                                for (array, 0..) |constant, i| {
                                    try if (i == 0)
                                        writer.print("{}", .{Formater(Constant).wrap(constant)})
                                    else
                                        writer.print(", {}", .{Formater(Constant).wrap(constant)});
                                }
                                try writer.writeByte(']');
                            }
                        },
                        .null_ptr => try writer.writeAll("null"),
                        .zero_initializer => try writer.writeAll("zero_initializer"),
                    }
                },
                Type => {
                    try switch (self.inner) {
                        .array => |array| writer.print("{}[{}]", .{ Formater(Type).wrap(array.child.*), array.size }),
                        .pointer => |ptr| writer.print("{}*", .{Formater(Type).wrap(ptr.child.*)}),
                        .int => |int| writer.print("{c}int{}", .{ @as(u8, if (int.signed) 's' else 'u'), int.bits }),
                        .label => writer.writeAll("label"),
                        .void => writer.writeAll("void"),
                    };
                },
                Value => {
                    try writer.print("{} ", .{Formater(Type).wrap(self.inner.type)});
                    try switch (self.inner.value) {
                        .constant => |c| if (is_string(self.inner.type)) writer.print("{s}", .{Formater(Constant).wrap(c)}) else writer.print("{}", .{Formater(Constant).wrap(c)}),
                        .ref => |r| switch (r) {
                            inline .argument, .instruction, .block => |inst| writer.print("%{}", .{inst.number}),
                            .global => |glob| writer.print("@{s}", .{glob.name}),
                        },
                    };
                },
                else => {},
            }
        }

        fn is_string(t: Type) bool {
            return switch (t) {
                inline .array, .pointer => |ptr| ptr.child.* == .int and ptr.child.int.bits == 8,
                else => false,
            };
        }
    };
}
