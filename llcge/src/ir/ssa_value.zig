const std = @import("std");
const Allocator = std.mem.Allocator;
const utils = @import("utils");

const meta = @import("../meta.zig");
const Type = @import("./type.zig");

pub const Use = struct {
    /// Id of the type of ptr, it uses to downcast ptr in the method `try_downcast`.
    type_id: utils.TypeId,
    ptr: *anyopaque,
};

/// Id of the type of ptr, it uses to downcast ptr in the method `try_downcast`.
type_id: utils.TypeId,
/// Pointer to the real data that contain all useful data of the type.
ptr: *anyopaque,

index: usize,
type: Type,
// TODO: transform Use into weak ptr ?
// std.AutoArrayHashMap is used to make something like an HashSet (not the best).
uses: std.AutoArrayHashMap(Use, void),

const Self = @This();

pub fn init(comptime T: type, ptr: *T, ty: Type, index: usize, allocator: Allocator) Self {
    return Self{
        .ty = utils.meta.typeId(T),
        .ptr = @ptrCast(ptr),
        .index = index,
        .type = ty,
        .uses = std.AutoArrayHashMap(Use, void).init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.type.deinit();
    self.uses.deinit();
}

pub fn add_use(self: *Self, ptr: anytype) void {
    const ptr_info = @typeInfo(@TypeOf(ptr));
    if (ptr_info != .pointer)
        @compileError("op must be a pointer.");

    self.uses.put(Use{
        .ty = utils.meta.typeId(ptr_info.pointer.child),
        .ptr = @ptrCast(ptr),
    }, void{});
}

pub fn remove_use(self: *Self, ptr: anytype) void {
    const ptr_info = @typeInfo(@TypeOf(ptr));
    if (ptr_info != .pointer)
        @compileError("op must be a pointer.");

    self.uses.orderedRemove(Use{
        .ty = utils.meta.typeId(ptr_info.pointer.child),
        .ptr = @ptrCast(ptr),
    });
}

pub fn try_downcast(self: Self, comptime T: type) ?*const T {
    if (self.ty == T)
        return @as(*const T, self.ptr);

    return null;
}
