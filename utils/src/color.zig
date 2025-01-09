const std = @import("std");
const Lazy = @import("./lazy.zig").Lazy;

var should_color = Lazy(bool, has_colors).init();

fn has_colors() bool {
    const CLICOLOR_FORCE = std.process.hasEnvVarConstant("CLICOLOR_FORCE");
    const NO_COLOR = std.process.hasEnvVarConstant("NO_COLOR");

    return CLICOLOR_FORCE or !NO_COLOR or std.io.getStdOut().supportsAnsiEscapeCodes();
}

pub const Color = enum(u8) {
    red = 31,
    green,
    yellow,
    blue,
    magenta,
    cyan,

    const Self = @This();

    pub fn force_usage(usage: bool) void {
        should_color.get().* = usage;
    }

    pub fn str(self: Self) ?[5]u8 {
        if (should_color.get().*) {
            var buf: [5]u8 = undefined;
            _ = std.fmt.bufPrint(&buf, "\x1B[{}m", .{@intFromEnum(self)}) catch unreachable;
            return buf;
        } else {
            return null;
        }
    }

    pub fn reset() ?[]const u8 {
        if (should_color.get().*) {
            return "\x1B[0m";
        } else {
            return null;
        }
    }

    pub fn colorize(comptime self: Self, comptime text: []const u8) []const u8 {
        if (should_color.get().*) {
            return comptime std.fmt.comptimePrint("\x1B[{}m{s}\x1B[0m", .{ @intFromEnum(self), text });
        } else {
            return text;
        }
    }
};
