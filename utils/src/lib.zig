pub const Color = @import("./color.zig").Color;
pub const Lazy = @import("./lazy.zig").Lazy;

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
