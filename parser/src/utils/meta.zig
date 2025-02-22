const std = @import("std");

const ResultTypeParser = "Result";
const Field = struct { name: [:0]const u8, type: type };

/// returns the smallest natural integer type as a function of the number of elements `x`
/// Examples
/// 0 => u0
/// 1, 2 => u1
/// 3, 4 => u2 ...
fn min_int_tag_type(x: anytype) type {
    const T: type = @TypeOf(x);
    if (@typeInfo(T) != .int or @typeInfo(T).int.signedness != .unsigned)
        @compileError("min_int_tag_type requires an unsigned integer, found " ++ @typeName(T));

    return std.meta.Int(.unsigned, if (x <= 1) @intCast(x) else @intCast(@typeInfo(T).int.bits - @clz(x - 1)));
}

pub fn callable(comptime Fn: type, comptime parser: anytype) ?Fn {
    const fn_info = switch (@typeInfo(Fn)) {
        .@"fn" => |info| info,
        else => @compileError("the Fn type must be a function"),
    };
    const is_type = @TypeOf(parser) == type;
    const ParserType = if(is_type) parser else @TypeOf(parser);
    const type_info = @typeInfo(ParserType);

    // test if the type of `parser` is exactly the same as `Fn`
    if (type_info == .@"fn" and ParserType == Fn)
        return parser;

    // in the case of a "closure", we want the struct to have a `call` method
    if (type_info == .@"struct" and @hasDecl(ParserType, "call")) {
        const CallFn = @TypeOf(ParserType.call);

        // checks whether the structure has a simple call function
        // (as requested by the Fn type)
        if (CallFn == Fn)
            return ParserType.call;
        
        const call_info = @typeInfo(CallFn).@"fn";
        // I assume that if `is_generic` is true and call takes itself as 1st
        // parameter then it must have the form fn(@This(), ...) return_type
        if (call_info.params.len >= 1 and call_info.params[0].type == ParserType and call_info.return_type == fn_info.return_type) {
            if (is_type)
                @compileError("the method call cannot be take a 'self'-like argument");

            return struct {
                fn call(input: call_info.params[1].type.?) call_info.return_type.? {
                    return parser.call(input);
                }
            }.call;
        }
        
    }

    return null;
}

pub fn is_parser_like(comptime parser: anytype) bool {
    const T = @TypeOf(parser);
    return @hasDecl(T, "run") and @hasDecl(T, ResultTypeParser);
}

pub fn ParserLikeResult(comptime parser: anytype) type {
    if (!is_parser_like(parser))
        @compileError("the input must be a parser (or look like a parser).");

    const T = @TypeOf(parser);
    return get_struct_attribute(T, ResultTypeParser);
}

/// Get the attribute `attribute_name` in the struct `StructType`
pub fn get_struct_attribute(comptime StructType: type, comptime attribute_name: []const u8) type {
    if (@typeInfo(StructType) != .@"struct")
        @compileError("the input must be a structure");

    if (!@hasDecl(StructType, attribute_name))
        @compileError(std.fmt.comptimePrint("the structure {s} need to have a const '{s}' (a type)", .{ @typeName(StructType), attribute_name }));

    return @field(StructType, attribute_name);
}

/// Check in a list of parser if each parser has the same Value
pub fn ParsersCommonValue(comptime parsers: anytype) type {
    const ParsersType = @TypeOf(parsers);
    const parsers_type_info = @typeInfo(ParsersType);
    if (parsers_type_info != .@"struct")
        @compileError("expected tuple or struct argument, found " ++ @typeName(ParsersType));

    const fields = parsers_type_info.@"struct".fields;
    if (fields.len == 0)
        @compileError("expected to have elements but the tuple or struct is empty");

    const result_type_value = get_struct_attribute(fields[0].type, ResultTypeParser);

    for (fields[1..]) |f| {
        const field_type_value = get_struct_attribute(f.type, ResultTypeParser);
        if (result_type_value != field_type_value)
            @compileError(std.fmt.comptimePrint("incompatible types: '{s}' and '{s}'", .{ @typeName(result_type_value), @typeName(field_type_value) }));
    }

    return result_type_value;
}

/// Transform a list of parser into a union of each value return be each parser
pub fn UnionFromParsers(comptime parsers: anytype) type {
    const ParsersType = @TypeOf(parsers);
    const parsers_type_info = @typeInfo(ParsersType);
    if (parsers_type_info != .@"struct")
        @compileError("expected tuple or struct argument, found " ++ @typeName(ParsersType));

    const fields = parsers_type_info.@"struct".fields;
    if (fields.len == 0)
        @compileError("expected to have elements but the tuple or struct is empty");

    comptime var values: [fields.len]Field = undefined;

    for (fields, 0..) |f, i|
        values[i] = .{ .name = f.name, .type = get_struct_attribute(f.type, ResultTypeParser) };

    return CreateUnionEnum(values.len, values);
}

pub fn CreateUnionEnum(comptime N: usize, comptime types: [N]Field) type {
    var union_fields: [N]std.builtin.Type.UnionField = undefined;
    var enum_fields: [N]std.builtin.Type.EnumField = undefined;
    for (types, 0..) |field, i| {
        union_fields[i] = .{
            .name = field.name,
            .type = field.type,
            .alignment = if (@sizeOf(field.type) > 0) @alignOf(field.type) else 0,
        };

        enum_fields[i] = .{ .name = field.name, .value = i };
    }

    const enum_type = @Type(.{ .@"enum" = .{
        .tag_type = min_int_tag_type(N),
        .is_exhaustive = true,
        .decls = &.{},
        .fields = &enum_fields,
    } });

    return @Type(.{
        .@"union" = .{
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
    if (parsers_type_info != .@"struct") {
        @compileError("expected tuple or struct argument, found " ++ @typeName(ParsersType));
    }

    const fields = parsers_type_info.@"struct".fields;
    const is_tuple = parsers_type_info.@"struct".is_tuple;

    comptime var values: [fields.len]Field = undefined;
    var real_len = 0;

    for (fields) |f| {
        const T = get_struct_attribute(f.type, ResultTypeParser);
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
    for (0..size) |i| {
        const field = types[i];
        struct_tuple_fields[i] = .{
            .name = field.name,
            .type = field.type,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = if (@sizeOf(field.type) > 0) @alignOf(field.type) else 0,
        };
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .backing_integer = null,
            .is_tuple = is_tuple,
            .decls = &.{},
            .fields = &struct_tuple_fields,
        },
    });
}

pub fn StructLen(comptime T: type) comptime_int {
    const parsers_type_info = @typeInfo(T);
    if (parsers_type_info != .@"struct") {
        @compileError("expected tuple or struct argument, found " ++ @typeName(T));
    }

    const fields = parsers_type_info.@"struct".fields;
    return fields.len;
}
