const Block = @import("./block.zig");
const Type = @import("./types.zig").Type;
const Value = @import("./value.zig").Value;

pub const OpCode = union(enum) {
    pub const Load = struct {
        element: Type,
        pointer: Value,
    };

    pub const Store = struct {
        pointer: Value,
        value: Value,
    };

    // Memory Access and Addressing Operands
    alloca: Type,
    load: Load,
    store: Store,

    // Control Flow Operands
    ret: Value,

    const Self = @This();

    pub fn getReturnValue(self: Self, instruction: *Instruction) Value {
        return switch (self) {
            .alloca => |alloca| Value.fromInstruction(alloca, instruction),
            .load => |load| Value.fromInstruction(load.element, instruction),
            .store, .ret => Value.Void,
        };
    }
};

pub const Instruction = struct {
    parent: *Block,
    number: usize,
    op_code: OpCode,

    const Self = @This();

    pub inline fn getReturnValue(self: *Self) Value {
        return self.op_code.getReturnValue(self);
    }
};
