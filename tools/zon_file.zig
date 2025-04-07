const std = @import("./zon_file/parser.zig");
const Allocator = std.mem.Allocator;

const parser = @import("./zon_file/parser.zig");


path: []const u8,
allocator: Allocator,
// source must be pass into the struct and it need to be allocated. 
source: []const u8,
content: parser.Value,

pub const Error = error {
    IllformedFile,
    InvalidKey,
} || std.fs.File.OpenError || std.fs.File.StatError || std.mem.Allocator.Error;

const Self = @This();

pub fn parse(path: []const u8, allocator: Allocator) !Self {
    const file = try std.fs.cwd().openFile(path, .{});
    const stat = try file.stat();
    const source = try file.readToEndAlloc(allocator, @as(stat.size, usize));

    return switch (parser.parse(source, allocator)) {
        .err => Error.IllformedFile,
        .ok => |result| if (result.second.len != 0) Error.IllformedFile
        else result.first,
    };
}

pub fn get(self: Self, long_key: []const u8) !*parser.Value {
    var it = std.mem.splitScalar(u8, long_key, '.');
    var value = &self.content;

    while (it.next()) |key| {
        value = switch (value.*) {
            .object => |obj| obj.getPtr(key) orelse return Error.InvalidKey,
            else => return Error.InvalidKey,
        };
    }

    return value;
}
