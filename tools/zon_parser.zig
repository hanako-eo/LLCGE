const std = @import("std");
const Allocator = std.mem.Allocator;

const parser = @import("parser");

const Value = union(enum) {
    int: i64,
    @"enum": []const u8,
    string: []const u8,
    object: std.StringHashMap(Value),

    const Self = @This();

    fn into_int(value: i64) Self {
        return Self{ .int = value };
    }

    fn into_string(value: []const u8) Self {
        return Self{ .string = value };
    }

    fn into_enum(value: struct { u8, []const u8 }) Self {
        return Self{ .@"enum" = value.@"1" };
    }

    fn into_object(list: std.ArrayList(struct { []const u8, Value })) Self {
        var map = std.StringHashMap(Value).init(list.allocator);
        for (list.items) |item| {
            const key, const value = item;
            map.put(key, value) catch @panic("oom");
        }
        list.deinit();
        return Self{ .object = map };
    }
};

const at = parser.chars.char('@');
const escape = parser.chars.char('\\');
const quote = parser.chars.char('"');
const dot = parser.chars.char('.');
const comma = parser.chars.char(',');
const open_brace = parser.chars.char('{');
const close_brace = parser.chars.char('}');

const ws = parser.bytes.take_while(parser.chars.whitespace, .many_times);
fn whitespaces(comptime p: anytype) parser.Parser(parser.meta.ParserLikeResult(p)) {
    return parser.sequence.delimited(ws, p, ws);
}

fn IntParser(comptime base: u8) type {
    return struct {
        pub fn call(raw: []const u8) i64 {
            // TODO: change the panic into better error handling
            return std.fmt.parseInt(i64, raw, base) catch @panic("oom");
        }
    };
}

const string_content = parser.bytes.escaped(parser.bytes.take_until(quote.or_else(escape), .many_times), '\\', parser.chars.any_char);
const binary_int = parser.sequence.preceded(parser.branch.choice(.{
    parser.bytes.tag("0b"),
    parser.bytes.tag("0B"),
}), parser.bytes.take_while(parser.chars.binary, .at_least_once)).map(i64, IntParser(2));
const octal_int = parser.sequence.preceded(parser.branch.choice(.{
    parser.bytes.tag("0o"),
    parser.bytes.tag("0O"),
}), parser.bytes.take_while(parser.chars.octal, .at_least_once)).map(i64, IntParser(8));
const decimal_int = parser.bytes.take_while(parser.chars.digit, .at_least_once).map(i64, IntParser(10));
const hexadecimal_int = parser.sequence.preceded(parser.branch.choice(.{
    parser.bytes.tag("0x"),
    parser.bytes.tag("0X"),
}), parser.bytes.take_while(parser.chars.hex, .at_least_once)).map(i64, IntParser(16));

const ident = parser.branch.choice(.{
    // case normal ident
    parser.bytes.take_while(parser.chars.alphanum, .at_least_once),
    // case string ident
    parser.sequence.preceded(at, string),
});

const string = parser.sequence.delimited(quote, string_content, quote);
const integer = parser.branch.choice(.{
    // case binary number
    &binary_int,
    // case octal number
    &octal_int,
    // case decimal number
    &decimal_int,
    // case hexdecimal number
    &hexadecimal_int,
});

const object = parser.sequence.delimited(
    dot.and_then(open_brace),
    parser.sequence.terminated(parser.alloc.separated_list(
        struct { []const u8, Value },
        parser.sequence.separated_pair(
            whitespaces(parser.sequence.preceded(dot, ident)),
            parser.chars.char('='),
            value_parser,
        ),
        whitespaces(comma),
        .many_times,
        .optional_separation,
        std.ArrayList,
    ), comma.opt()),
    close_brace
);

pub fn zon_value(input: []const u8, allocator: Allocator) parser.ParseResult(Value, []const u8) {
    return whitespaces(parser.branch.choice(.{
        integer.map(Value, Value.into_int),
        string.map(Value, Value.into_string),
        dot.and_then(ident).map(Value, Value.into_enum),
        object.map(Value, Value.into_object)
    })).run(input, allocator);
}

const value_parser = parser.Parser(Value).init(zon_value);
