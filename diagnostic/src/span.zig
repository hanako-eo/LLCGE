const Location = @import("./location.zig");
const Source = @import("./source.zig");

source: Source,
location: Location,

const Self = @This();

pub fn start(self: Self) Location.LineColumn {
    return self.location.start;
}

pub fn end(self: Self) Location.LineColumn {
    return self.location.end;
}
