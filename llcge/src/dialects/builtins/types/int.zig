const std = @import("std");

const Context = @import("../../../context.zig");
const Type = @import("../../../ir/type.zig");

pub const Signedness = enum {
    signless,
    signed,
    unsigned,
};

signed: Signedness = .signless,
bits: u16,

const Self = @This();

pub const I1 = Type.static_init(Self, &Self.init(.signless, 1));
pub const I8 = Type.static_init(Self, &Self.init(.signed, 8));
pub const U8 = Type.static_init(Self, &Self.init(.unsigned, 8));
pub const I16 = Type.static_init(Self, &Self.init(.signed, 16));
pub const U16 = Type.static_init(Self, &Self.init(.unsigned, 16));
pub const I32 = Type.static_init(Self, &Self.init(.signed, 32));
pub const U32 = Type.static_init(Self, &Self.init(.unsigned, 32));
pub const I64 = Type.static_init(Self, &Self.init(.signed, 64));
pub const U64 = Type.static_init(Self, &Self.init(.unsigned, 64));
pub const I128 = Type.static_init(Self, &Self.init(.signed, 128));
pub const U128 = Type.static_init(Self, &Self.init(.unsigned, 128));

pub fn init(_: *const Context, signed: Signedness, bits: u16) Self {
    return Self{
        .signed = if (bits == 1) .signless else signed,
        .bits = bits,
    };
}

/// Return the alignement of an int (it's the same as the size)
pub fn align_of(self: *const Self) Type.Alignment {
    return @enumFromInt(self.size_of());
}

pub fn size_of(self: *const Self) usize {
    const size = std.math.divCeil(usize, self.bits, 8) catch unreachable;
    return std.math.ceilPowerOfTwo(usize, size) catch unreachable;
}

pub fn is_same(self: *const Self, other: *const Self) bool {
    return self.signed == self.signed and self.bits == other.bits;
}
