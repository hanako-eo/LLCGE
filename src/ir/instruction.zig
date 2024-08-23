const std = @import("std");

const Block = @import("./block.zig");
const Type = @import("./types.zig").Type;
const Value = @import("./value.zig").Value;

pub const OpCode = union(enum) {
    pub const Alloca = struct {
        type: Type,
        size: usize,

        pub fn init(@"type": Type, size: usize) Self {
            std.debug.assert(size > 0);
            return .{ .alloca = .{ .type = @"type", .size = size } };
        }
    };

    pub const Load = struct {
        element: Type,
        pointer: Value,

        pub fn init(element: Type, pointer: Value) Self {
            std.debug.assert(pointer.type == .pointer);
            std.debug.assert(pointer.type.pointer.child.eq(element));

            return .{ .load = .{ .element = element, .pointer = pointer } };
        }
    };

    pub const Store = struct {
        pointer: Value,
        value: Value,

        pub fn init(pointer: Value, value: Value) Self {
            std.debug.assert(pointer.type == .pointer);
            std.debug.assert(pointer.type.pointer.child.* == value.type);

            return .{ .store = .{ .pointer = pointer, .value = value } };
        }
    };

    pub const AccessPtr = struct {
        pointer: Value,
        indexes: []const Value,

        pub fn init(pointer: Value, indexes: []const Value) Self {
            std.debug.assert(pointer.type == .array or pointer.type == .pointer);
            for (indexes) |index|
                std.debug.assert(index.type == .int);

            return .{ .access_ptr = .{ .pointer = pointer, .indexes = indexes } };
        }
    };

    pub const Access = struct {
        pointer: Value,
        indexes: []const Value,

        pub fn init(pointer: Value, indexes: []const Value) Self {
            std.debug.assert(pointer.type == .array or pointer.type == .pointer);
            for (indexes) |index|
                std.debug.assert(index.type == .int);

            return .{ .access = .{ .pointer = pointer, .indexes = indexes } };
        }
    };

    pub const Cast = struct {
        result_type: Type,
        base: Value,

        pub fn init(result_type: Type, base: Value) Self {
            std.debug.assert(base.type.castable(result_type));

            return .{ .cast = .{ .result_type = result_type, .base = base } };
        }
    };

    pub const Return = struct {
        value: Value,

        pub fn init(value: ?Value) Self {
            return .{ .ret = .{ .value = value orelse Value.Void } };
        }
    };

    // Memory Access and Addressing Operands
    alloca: Alloca,
    load: Load,
    store: Store,
    access: Access,
    access_ptr: AccessPtr,

    // Type Operations
    cast: Cast,

    // Control Flow Operands
    ret: Return,

    const Self = @This();

    fn getPtrChild(t: Type) *Type {
        return switch (t) {
            inline .array, .pointer => |ptr| ptr.child,
            else => unreachable,
        };
    }

    pub fn getReturnValue(self: Self, instruction: *Instruction) Value {
        return switch (self) {
            .alloca => |alloca| Value.instruction(alloca.type, instruction),
            .load => |load| Value.instruction(load.element, instruction),
            .access_ptr => |access_ptr| Value.instruction(.{ .pointer = .{ .child = getPtrChild(access_ptr.pointer.type) } }, instruction),
            .access => |access| Value.instruction(getPtrChild(access.pointer.type).*, instruction),
            .cast => |cast| Value.instruction(cast.result_type, instruction),
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
