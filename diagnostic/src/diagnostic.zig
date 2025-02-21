const std = @import("std");
const Color = @import("utils").Color;
const Label = @import("./label.zig");
const Location = @import("./location.zig");
const Severity = @import("./lib.zig").Severity;
const Source = @import("./source.zig");

message: []const u8,
source: Source,
severity: Severity,
location: Location,
labels: std.ArrayList(Label),

const Self = @This();

pub fn init(severity: Severity, source: Source, location: Location, message: []const u8, labels: std.ArrayList(Label)) Self {
    return Self{ .message = message, .location = location, .source = source, .severity = severity, .labels = labels };
}

pub inline fn init_empty(severity: Severity, source: Source, location: Location, message: []const u8, allocator: std.mem.Allocator) Self {
    return Self.init(severity, source, location, message, std.ArrayList(Label).init(allocator));
}

pub fn deinit(self: Self) void {
    self.labels.deinit();
}

pub fn get_source(self: Self) Source {
    return self.source;
}

pub fn add_note(self: *Self, source: Source, location: Location, note: []const u8) !void {
    return self.labels.append(Label.init(source, location, note));
}

pub fn format(
    self: Self,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    base_writer: anytype,
) !void {
    const writer = Writer.init(base_writer);

    try format_label(switch (self.severity) {
        .info => Color.magenta.colorize("info"),
        .warning => Color.yellow.colorize("warning"),
        .@"error" => Color.red.colorize("error"),
    }, switch (self.severity) {
        .info => Color.magenta,
        .warning => Color.yellow,
        .@"error" => Color.red,
    }, self.source, self.location, self.message, writer);

    for (self.labels.items) |label| {
        try format_label(Color.cyan.colorize("note"), Color.cyan, label.span.source, label.span.location, label.note, writer);
    }
}

fn format_label(tag: []const u8, color: Color, source: Source, location: Location, message: ?[]const u8, writer: Writer) !void {
    const path = source.path orelse "~memory";
    var lines = source.get_lines(location.start.line);

    if (message) |note| {
        try writer.print("{s} in {s}:{}:{}:\n -> {s}\n", .{ tag, path, location.start.line, location.start.column, note });
    } else {
        try writer.print("{s} in {s}:{}:{}:\n", .{ tag, path, location.start.line, location.start.column });
    }

    const max_line_number_size = std.math.log10_int(location.end.line) + 1;
    var line: []const u8 = undefined;
    if (location.end.line == location.start.line) {
        line = lines.next() orelse return;
        try writer.writeByte(' ');
        try writer.writeInt(location.start.line, max_line_number_size);
        try writer.print(" | {s}\n", .{line});
        try writer.writeRepeatedByte(' ', max_line_number_size + 1);
        try writer.writeAll(" | ");
        try writer.writeRepeatedByte(' ', location.start.column - 1);
        try writer.writeWithColor(color, location.end.column - location.start.column, struct {
            fn call(w: Writer, i: usize) !void {
                try w.writeRepeatedByte('^', i);
            }
        }.call);
    } else {
        for (location.start.line..(location.end.line + 1)) |i| {
            line = lines.next() orelse return;
            try writer.writeByte(' ');
            try writer.writeInt(i, max_line_number_size);
            try writer.writeAll(" | ");
            try writer.writeWithColor(color, if (i == location.start.line) @as(u8, '/') else @as(u8, '|'), Writer.writeByte);
            try writer.print(" {s}\n", .{line});
        }
        try writer.writeRepeatedByte(' ', max_line_number_size + 4);

        try writer.writeWithColor(color, location.end.column, struct {
            fn call(w: Writer, i: usize) !void {
                try w.writeByte('\\');
                try w.writeRepeatedByte('-', i - 1);
                try w.writeByte('/');
            }
        }.call);
    }
    try writer.writeByte('\n');
}

const Writer = struct {
    base: std.io.AnyWriter,

    pub fn init(base: std.io.AnyWriter) Writer {
        return Writer{ .base = base };
    }

    pub fn writeInt(self: Writer, value: usize, width: usize) !void {
        try std.fmt.formatInt(value, 10, .lower, .{ .width = width }, self.base);
    }

    pub fn writeRepeatedByte(self: Writer, char: u8, repetition: usize) !void {
        var i: usize = 0;
        while (i < repetition) : (i += 1) {
            try self.base.writeByte(char);
        }
    }

    pub fn writeWithColor(self: Writer, color: Color, ctx: anytype, func: fn (Writer, @TypeOf(ctx)) anyerror!void) !void {
        if (color.str()) |c| {
            try self.base.writeAll(&c);
        }
        try func(self, ctx);
        if (Color.reset()) |c| {
            try self.base.writeAll(c);
        }
    }

    pub fn writeByte(self: Writer, char: u8) !void {
        try self.base.writeByte(char);
    }

    pub fn writeAll(self: Writer, bytes: []const u8) !void {
        try self.base.writeAll(bytes);
    }

    pub fn print(self: Writer, comptime format_str: []const u8, args: anytype) !void {
        try self.base.print(format_str, args);
    }
};
