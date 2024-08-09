// used because we cannot store value in the error in zig for now
pub fn Result(comptime T: type, comptime E: type) type {
    return union(enum) {
        ok: T,
        err: E
    };
}
