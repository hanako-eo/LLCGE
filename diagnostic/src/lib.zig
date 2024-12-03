pub const Diagnostic = @import("./diagnostic.zig");
pub const Label = @import("./label.zig");
pub const Location = @import("./location.zig");
pub const Source = @import("./source.zig");
pub const Span = @import("./span.zig");

pub const Severity = enum {
    info,
    warning,
    @"error",
};
