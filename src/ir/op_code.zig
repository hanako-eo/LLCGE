const Instruction = @import("./instruction.zig");
const Type = @import("./types.zig").Type;
const Value = @import("./value.zig").Value;

pub const OpCode = union(enum) {
    pub const Alloca = @import("./op_codes/alloca.zig");
    pub const Load = @import("./op_codes/load.zig");
    pub const Store = @import("./op_codes/store.zig");
    pub const AccessPtr = @import("./op_codes/access_ptr.zig");
    pub const Access = @import("./op_codes/access.zig");

    pub const Cast = @import("./op_codes/cast.zig");

    pub const Jump = @import("./op_codes/jump.zig");
    pub const ConditionalJump = @import("./op_codes/conditional_jump.zig");
    pub const Return = @import("./op_codes/return.zig");

    // Memory Access and Addressing Operands
    alloca: Alloca,
    load: Load,
    store: Store,
    access: Access,
    access_ptr: AccessPtr,

    // Type Operations
    cast: Cast,

    // Control Flow Operands
    jump: Jump,
    jumpc: ConditionalJump,
    ret: Return,

    const Self = @This();

    fn getPtrChild(t: Type) *Type {
        return switch (t) {
            inline .array, .pointer => |ptr| ptr.child,
            else => unreachable,
        };
    }

    pub inline fn getReturnValue(self: Self, instruction: *Instruction) Value {
        return switch (self) {
            inline else => |op| op.getReturnValue(instruction),
        };
    }
};
