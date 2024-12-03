path: ?[]const u8,
data: []const u8,

const Self = @This();

pub fn init(data: []const u8, path: []const u8) Self {
    return Self { .data = data, .path = path };
}

pub fn init_unnamed(data: []const u8) Self {
    return Self { .data = data, .path = null };
}
