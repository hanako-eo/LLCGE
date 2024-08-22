const std = @import("std");
const Allocator = std.mem.Allocator;
const File = std.fs.File;

const Global = @import("../global.zig");
const Module = @import("../module.zig");
const Type = @import("../types.zig").Type;

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
    if (module.source) |source| {
        try self.writer.print("module_source \"{s}\"\n", .{source});
    }

    try self.writer.writeByte('\n');

    var globals_iterator = module.globals.iterator();
    while (globals_iterator.next()) |entry| {
        try self.codegen_global(entry.key_ptr.*, entry.value_ptr);
    }
}

pub fn codegen_global(self: Self, name: []const u8, global: *Global) !void {
    try self.writer.print("define {s} {} @{s} = {}\n", .{ if (global.is_constant) "local const" else "global", Type{ .pointer = .{ .child = &global.value.type } }, name, global.value });
}
