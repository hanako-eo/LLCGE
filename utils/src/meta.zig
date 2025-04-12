const std = @import("std");

const TypeId = @import("./lib.zig").TypeId;

// based on: https://github.com/ziglang/zig/issues/19858#issuecomment-2366395819
pub fn typeId(comptime T: type) TypeId {
    const a = std.hash.Wyhash.hash(3832269059401244599, @typeName(T));
    const b = std.hash.Wyhash.hash(5919152850572607287, @typeName(T));
    return @bitCast([2]u64{ a, b });
}
