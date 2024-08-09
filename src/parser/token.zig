const Result = @import("../utils/result.zig").Result;

pub fn Token(comptime T: type) type {
    return struct {
        value: T,

        const Self = @This();

        pub fn init(value: T) Self {
            return Self { .value = value };
        }
    };
}

// used because we cannot store value in the error in zig for now
pub fn TokenResult(comptime T: type, comptime E: type) type {
    return Result(Token(T), E);
}
