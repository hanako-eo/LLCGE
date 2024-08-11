const std = @import("std");

/// returns the smallest natural integer type as a function of the number of elements `x`
/// Examples
/// 0 => u0
/// 1, 2 => u1
/// 3, 4 => u2 ...
fn minIntTagType(x: anytype) type {
    const T: type = @TypeOf(x);
    if (@typeInfo(T) != .Int or @typeInfo(T).Int.signedness != .unsigned)
        @compileError("minBitsSize requires an unsigned integer, found " ++ @typeName(T));

    if (x <= 1)
        return @intCast(x);

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
    comptime var values: [fields.len]struct { []const u8, type } = undefined;

    inline for (fields, 0..) |f, i|
        values[i] = .{ f.name, getStructAttribute(f.type, "Value") };

    return CreateUnionEnum(values.len, values);
}

pub fn CreateUnionEnum(comptime N: usize, comptime types: [N]struct { []const u8, type }) type {
    var union_tuple_fields: [N]std.builtin.Type.UnionField = undefined;
    var enum_fields: [N]std.builtin.Type.EnumField = undefined;
    inline for (types, 0..) |value, i| {
        const name, const T = value;

        union_tuple_fields[i] = .{
            .name = name,
            .type = T,
            .alignment = if (@sizeOf(T) > 0) @alignOf(T) else 0,
        };

        enum_fields[i] = .{ .name = name, .value = i };
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
            .fields = &union_tuple_fields,
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
