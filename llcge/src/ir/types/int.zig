signed: bool = true,
bits: u16,

const Self = @This();

pub fn eq(self: Self, other: Self) bool {
    return self.signed == other.signed and self.bits == other.bits;
}

pub fn size_of(self: Self) usize {
    return self.bits / 8;
}
