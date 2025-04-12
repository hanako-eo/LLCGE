const std = @import("std");
const utils = @import("utils");

pub fn tuple_remove_from_indices(comptime T: type, comptime indices: []const usize) type {
    const type_info = @typeInfo(T);
    if (type_info != .@"struct")
        @panic("T must be a tuple (or a struct).");

    comptime var fields: [type_info.@"struct".fields.len - indices.len]std.builtin.Type.StructField = undefined;
    var j: usize = 0;
    for (type_info.@"struct".fields, 0..) |field, i| {
        if (utils.mem.binary_search(usize, indices, i) != null)
            continue;

        fields[j] = field;
        j += 1;
    }

    return @Type(std.builtin.Type{
        .@"struct" = .{
            .layout = .auto,
            .fields = fields,
            .decls = &.{},
            .is_tuple = true,
        },
    });
}

pub fn merge_tuples(first: anytype, second: anytype) MergedTuples(@TypeOf(first), @TypeOf(second)) {
    const T = @TypeOf(first);
    const U = @TypeOf(second);
    const Merged = MergedTuples(T, U);
    const value: Merged = undefined;

    inline for (@typeInfo(T).@"struct".fields) |field| {
        @field(value, field.name) = @field(first, field.name);
    }

    inline for (@typeInfo(U).@"struct".fields, @typeInfo(T).@"struct".fields.len..) |field, i| {
        var num_buf: [128]u8 = undefined;
        const field_name = std.fmt.bufPrintZ(&num_buf, "{d}", .{i}) catch unreachable;
        @field(value, field_name) = @field(second, field.name);
    }

    return value;
}

fn MergedTuples(comptime T: type, comptime U: type) type {
    const T_info = @typeInfo(T);
    if (T_info != .@"struct")
        @compileError("T must be a struct.");

    const U_info = @typeInfo(U);
    if (U_info != .@"struct")
        @compileError("T must be a struct.");

    var fields: [T_info.@"struct".fields.len + U_info.@"struct".fields.len]std.builtin.Type.StructField = undefined;
    std.mem.copyForwards(std.builtin.Type.StructField, &fields, T_info.@"struct".fields);

    for (U_info.@"struct".fields, T_info.@"struct".fields.len..) |field, i| {
        var num_buf: [128]u8 = undefined;
        fields[i] = .{
            .name = std.fmt.bufPrintZ(&num_buf, "{d}", .{i}) catch field.name,
            .type = field.type,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = if (@sizeOf(field.type) > 0) @alignOf(field.type) else 0,
        };
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &fields,
            .decls = &.{},
            .is_tuple = true,
        },
    });
}

pub fn vtable_method(comptime T: type, f: anytype) t: {
    const Fn = @TypeOf(f);
    break :t *const cast_anyopaque_fn(T, @typeInfo(Fn).pointer.child);
} {
    const Fn = @TypeOf(f);
    return @as(*const cast_anyopaque_fn(T, @typeInfo(Fn).pointer.child), @ptrCast(f));
}

fn cast_anyopaque_fn(comptime T: type, comptime func: type) type {
    const fn_info = @typeInfo(func);
    if (fn_info != .@"fn")
        @compileError("the second argument must be a function.");

    comptime var params: [fn_info.@"fn".params.len]std.builtin.Type.Fn.Param = undefined;
    for (fn_info.@"fn".params, 0..) |param, i| {
        params[i] = .{
            .is_generic = param.is_generic,
            .is_noalias = param.is_noalias,
            .type = if (param.type == *const T) *const anyopaque else param.type,
        };
    }

    return @Type(std.builtin.Type{
        .@"fn" = .{
            .calling_convention = fn_info.@"fn".calling_convention,
            .is_generic = fn_info.@"fn".is_generic,
            .is_var_args = fn_info.@"fn".is_var_args,
            .return_type = fn_info.@"fn".return_type,
            .params = &params,
        },
    });
}
