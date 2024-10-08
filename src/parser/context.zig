cursor: usize,
dirty_cursor: usize,

input: []const u8,

const Self = @This();

pub fn init(input: []const u8) Self {
    return Self{ .cursor = 0, .dirty_cursor = 0, .input = input };
}

pub fn commit(self: *Self) void {
    self.cursor = self.dirty_cursor;
}

pub fn uncommit(self: *Self) void {
    self.dirty_cursor = self.cursor;
}

pub fn get_dirty_residual(self: Self) []const u8 {
    return self.input[self.dirty_cursor..];
}

pub fn get_residual(self: Self) []const u8 {
    return self.input[self.cursor..];
}
