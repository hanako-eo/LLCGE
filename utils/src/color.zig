const std = @import("std");
const Lazy = @import("./lazy.zig").Lazy;

var should_color = Lazy(bool, has_colors);

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

    pub fn colorize(comptime self: Self, comptime text: []const u8) []const u8 {
        if (should_color.get().*) {
            return comptime std.fmt.comptimePrint("\u{001B}[{}m{s}\u{001B}[0m", .{ @intFromEnum(self), text });
        } else {
            return text;
        }
    }
};
