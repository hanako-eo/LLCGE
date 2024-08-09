// used because we cannot store value in the error in zig for now
pub fn Result(comptime T: type, comptime E: type) type {
    return union(enum) { ok: T, err: E };
}

pub fn Expectation(comptime E: type, comptime A: type) type {
    return struct { expected: E, actual: A };
}

pub fn ExpectationSimple(comptime T: type) type {
    return Expectation(T, T);
}
