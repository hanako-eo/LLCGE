const std = @import("std");

const Field = struct { name: [:0]const u8, type: type };

/// returns the smallest natural integer type as a function of the number of elements `x`
/// Examples
/// 0 => u0
/// 1, 2 => u1
/// 3, 4 => u2 ...
fn minIntTagType(x: anytype) type {
    const T: type = @TypeOf(x);
    if (@typeInfo(T) != .Int or @typeInfo(T).Int.signedness != .unsigned)
        @compileError("minBitsSize requires an unsigned integer, found " ++ @typeName(T));

    return std.meta.Int(.unsigned, if (x <= 1) @intCast(x) else @intCast(@typeInfo(T).Int.bits - @clz(x - 1)));
}

/// Get the attribute `attribute_name` in the struct `StructType`
pub fn getStructAttribute(comptime StructType: type, comptime attribute_name: []const u8) type {
    const struct_info = @typeInfo(StructType);

    if (struct_info != .Struct)
        @compileError("The input need to be a structure");

    const decls = struct_info.Struct.decls;

    for (decls) |decl| {
        if (std.mem.eql(u8, decl.name, attribute_name))
            return @field(StructType, attribute_name);
    }

    @compileError(std.fmt.comptimePrint("The structure {s} need to have a const '{s}' (a type)", .{ @typeName(StructType), attribute_name }));
}

/// Transform a list of parser into a union of each value return be each parser
pub fn UnionFromParsers(comptime parsers: anytype) type {
    const ParsersType = @TypeOf(parsers);
    const parsers_type_info = @typeInfo(ParsersType);
    if (parsers_type_info != .Struct) {
        @compileError("expected tuple or struct argument, found " ++ @typeName(ParsersType));
    }

    const fields = parsers_type_info.Struct.fields;
    comptime var values: [fields.len]Field = undefined;

    inline for (fields, 0..) |f, i|
        values[i] = .{ .name = f.name, .type = getStructAttribute(f.type, "Value") };

    return CreateUnionEnum(values.len, values);
}

pub fn CreateUnionEnum(comptime N: usize, comptime types: [N]Field) type {
    var union_fields: [N]std.builtin.Type.UnionField = undefined;
    var enum_fields: [N]std.builtin.Type.EnumField = undefined;
    inline for (types, 0..) |field, i| {
        union_fields[i] = .{
            .name = field.name,
            .type = field.type,
            .alignment = if (@sizeOf(field.type) > 0) @alignOf(field.type) else 0,
        };

        enum_fields[i] = .{ .name = field.name, .value = i };
    }

    const enum_type = @Type(.{ .Enum = .{
        .tag_type = minIntTagType(N),
        .is_exhaustive = true,
        .decls = &.{},
        .fields = &enum_fields,
    } });

    return @Type(.{
        .Union = .{
            .layout = .auto,
            .tag_type = enum_type,
            .decls = &.{},
            .fields = &union_fields,
        },
    });
}

/// Transform a list of parser into a union of each value return be each parser
pub fn StructFromParsers(comptime parsers: anytype) type {
    const ParsersType = @TypeOf(parsers);
    const parsers_type_info = @typeInfo(ParsersType);
    if (parsers_type_info != .Struct) {
        @compileError("expected tuple or struct argument, found " ++ @typeName(ParsersType));
    }

    const fields = parsers_type_info.Struct.fields;
    const is_tuple = parsers_type_info.Struct.is_tuple;

    comptime var values: [fields.len]Field = undefined;
    var real_len = 0;

    inline for (fields) |f| {
        const T = getStructAttribute(f.type, "Value");
        if (T == void)
            continue;

        var num_buf: [128]u8 = undefined;
        const name = if (is_tuple) std.fmt.bufPrintZ(&num_buf, "{d}", .{real_len}) catch f.name else f.name;

        values[real_len] = .{ .name = name, .type = T };

        real_len += 1;
    }

    return CreateUniqueStruct(real_len, &values, is_tuple);
}

pub fn CreateUniqueStruct(comptime size: usize, comptime types: []Field, comptime is_tuple: bool) type {
    var struct_tuple_fields: [size]std.builtin.Type.StructField = undefined;
    inline for (0..size) |i| {
        const field = types[i];
        struct_tuple_fields[i] = .{
            .name = field.name,
            .type = field.type,
            .default_value = null,
            .is_comptime = false,
            .alignment = if (@sizeOf(field.type) > 0) @alignOf(field.type) else 0,
        };
    }

    return @Type(.{
        .Struct = .{
            .layout = .auto,
            .backing_integer = null,
            .is_tuple = is_tuple,
            .decls = &.{},
            .fields = &struct_tuple_fields,
        },
    });
}

pub fn LenOfParsers(comptime parsers: anytype) comptime_int {
    const ParsersType = @TypeOf(parsers);
    const parsers_type_info = @typeInfo(ParsersType);
    if (parsers_type_info != .Struct) {
        @compileError("expected tuple or struct argument, found " ++ @typeName(ParsersType));
    }

    const fields = parsers_type_info.Struct.fields;
    return fields.len;
}
