pub const mem = @import("./mem.zig");
pub const meta = @import("./meta.zig");

pub const Color = @import("./color.zig").Color;
pub const Lazy = @import("./lazy.zig").Lazy;

pub const TypeId = u128;

pub fn Pair(comptime K: type, comptime V: type) type {
    return struct {
        first: K,
        second: V,

        const Self = @This();

        pub fn init(first: K, second: V) Self {
            return Self{ .first = first, .second = second };
        }
    };
}
