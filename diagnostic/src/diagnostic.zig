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

pub fn format(
    self: Self,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    const path = self.source.path orelse "~memory";
    const tag = switch (self.severity) {
        .info => Color.magenta.colorize("info"),
        .warning => Color.yellow.colorize("warning"),
        .@"error" => Color.red.colorize("error"),
    };

    try writer.print("{s} in {s}:{}:{}:\n -> {s}\n", .{ tag, path, self.location.start.line, self.location.start.column, self.message });
}
