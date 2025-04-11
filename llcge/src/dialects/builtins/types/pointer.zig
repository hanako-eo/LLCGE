const Context = @import("../../../context.zig");

const Self = @This();

pub fn init(_: *const Context) Self {
    return Self {}; 
}

pub fn align_of(_: Self) usize {
    // TODO: use a context to be able to set ptr in a size of 16, 32 or 64
    return @alignOf(*anyopaque);
}

pub fn size_of(_: Self) usize {
    // TODO: use a context to be able to set ptr in a size of 16, 32 or 64
    return @sizeOf(*anyopaque);
}

pub fn is_same(_: Self, _: Self) usize {
    return true;
}