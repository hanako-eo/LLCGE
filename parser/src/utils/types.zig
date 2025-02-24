// used because we cannot store value in the error in zig for now
pub fn Result(comptime T: type, comptime E: type) type {
    return union(enum) {
        ok: T,
        err: E,

        const Self = @This();

        pub fn Ok(value: T) Self {
            return Self{ .ok = value };
        }

        pub fn Err(value: E) Self {
            return Self{ .err = value };
        }
    };
}

pub fn Expectation(comptime E: type, comptime A: type) type {
    return struct { expected: E, actual: A };
}

pub fn ExpectationSimple(comptime T: type) type {
    return Expectation(T, T);
}

pub fn Unexpectation(comptime T: type) type {
    return T;
}
