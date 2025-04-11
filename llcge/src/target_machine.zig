pub const Endianness = enum {
    big,
    little,
    native,
};

pub const OptLevel = enum {
    no,
    default,
    small,
    fast,
    aggressive,
};

opt_level: OptLevel = .Default,
endianness: Endianness,
triple: []const u8,
pointer_size: usize,
