const std = @import("std");
const Label = @import("./label.zig");
const Severity = @import("./lib.zig").Severity;

message: []const u8,
source: []const u8,
severity: Severity,
labels: std.ArrayList(Label),

const Self = @This();

pub fn init(message: []const u8, source: []const u8, severity: Severity, labels: std.ArrayList(Label)) Self {
    return Self{ .message = message, .source = source, .severity = severity, .labels = labels };
}

pub inline fn init_allocated(message: []const u8, source: []const u8, severity: Severity, allocator: std.mem.Allocator) Self {
    return Self.init(message, source, severity, std.ArrayList(Label).init(allocator));
}

pub inline fn init_unnamed(message: []const u8, severity: Severity, labels: std.ArrayList(Label)) Self {
    return Self.init(message, "", severity, labels);
}

pub inline fn init_unnamed_allocated(message: []const u8, severity: Severity, allocator: std.mem.Allocator) Self {
    return Self.init_allocated(message, "", severity, allocator);
}
