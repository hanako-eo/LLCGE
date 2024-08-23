const std = @import("std");
const Allocator = std.mem.Allocator;
const File = std.fs.File;

const Function = @import("../function.zig");
const Global = @import("../global.zig");
const instruction_zig = @import("../instruction.zig");
const Instruction = instruction_zig.Instruction;
const OpCode = instruction_zig.OpCode;
const Module = @import("../module.zig");
const Type = @import("../types.zig").Type;
const Value = @import("../value.zig").Value;

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
    try self.writer.print("define {s} {}* @{s} = {}\n", .{ if (global.is_constant) "local const" else "global", global.value.type, name, global.value });
}

pub fn codegen_function(self: Self, name: []const u8, function: *const Function) !void {
    try self.writer.print("define local {} @{s}(", .{ function.return_type, name });
    for (function.args.items, 0..) |arg, i| {
        try if (i == 0)
            self.writer.print("{} %{}", .{ arg.type, arg.number })
        else
            self.writer.print(", {} %{}", .{ arg.type, arg.number });
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
    try self.codegen_op_code(&instruction.op_code);
}

pub fn codegen_op_code(self: Self, op_code: *const OpCode) !void {
    switch (op_code.*) {
        inline .access, .access_ptr => |access| {
            try self.writer.print("access {}", .{access.pointer});
            for (access.indexes) |index|
                try self.writer.print(", {}", .{index});
        },
        .alloca => |alloca| try self.writer.print("alloca {}", .{alloca.type}),
        .cast => |cast| try self.writer.print("cast {}, {}", .{ cast.result_type, cast.base }),
        .load => |load| try self.writer.print("load {}, {}", .{ load.element, load.pointer }),
        .store => |store| try self.writer.print("store {}, {}", .{ store.value, store.pointer }),
        .ret => |ret| try if (ret.value.type == .void) self.writer.writeAll("ret void") else self.writer.print("ret {}", .{ret.value}),
    }

    try self.writer.writeByte('\n');
}
