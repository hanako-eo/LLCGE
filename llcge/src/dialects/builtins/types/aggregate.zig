const std = @import("std");
const Allocator = std.mem.Allocator;

const Context = @import("../../../context.zig");
const Type = @import("../../../ir/type.zig");

const Field = struct {
    ty: Type,
    offset: usize,
};

const Option = struct {
    alignment: ?Type.Alignment = null,
    is_packed: bool = false,
};

fields: []const Field,
alignment: Type.Alignment,
is_packed: bool,

allocator: Allocator,

const Self = @This();

pub fn init(context: *const Context, types: []const Type, option: Option) !Self {
    const is_alignment_set = option.alignment != null;

    var fields = try context.allocator.alloc(Field, types.len);
    var alignment = @intFromEnum(option.alignment orelse if (types.len == 0) Type.Alignment.@"0" else types[0].align_of());
    var o = 0;
    for (types, 0..) |ty, i| {
        fields[i] = Field{
            .ty = ty,
            .offset = o,
        };

        if (i < types.len - 1) {
            // compute next offset
            o = padding(o + ty.size_of(), types[i + 1].align_of());
        }

        if (is_alignment_set) {
            alignment = @max(alignment, @intFromEnum(ty.align_of()));
        }
    }

    return Self{
        .fields = fields,
        .is_packed = option.is_packed,
        .alignment = @enumFromInt(alignment),
        .allocator = context.allocator,
    };
}

pub fn deinit(self: Self) void {
    self.allocator.free(self.fields);
}

pub fn align_of(self: Self) usize {
    return self.alignment;
}

pub fn size_of(self: Self) usize {
    var s: usize = 0;
    if (self.is_packed) {
        for (self.fields) |field| {
            s += field.ty.size_of();
        }
    } else {
        const field = self.fields[self.fields.len - 1];

        return padding(field.offset + field.ty.size_of(), self.alignment);
    }
    return s;
}

pub fn offset_of(self: Self, index: usize) usize {
    return self.fields[index].offset;
}

pub fn is_same(self: Self, other: Self) usize {
    return self.size == other.size and self.child.is_same(other.child);
}

fn padding(x: usize, a: Type.Alignment) usize {
    return std.math.ceil(x / @intFromEnum(a)) * @intFromEnum(a);
}
