const Location = @import("./location.zig");
const Source = @import("./source.zig");
const Span = @import("./span.zig");

note: ?[]const u8 = null,
span: Span,

const Self = @This();

pub fn init(source: Source, location: Location, note: []const u8) Self {
    return Self{ .note = note, .span = Span{ .location = location, .source = source } };
}
