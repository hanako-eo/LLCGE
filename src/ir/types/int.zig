signed: bool = true,
bits: u16,

const Self = @This();

pub fn sizeOf(self: Self) usize {
    return self.bits / 8;
}
