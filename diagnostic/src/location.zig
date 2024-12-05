start: LineColumn,
end: LineColumn,

pub const LineColumn = struct {
    line: usize,
    column: usize,
};

const Self = @This();

pub fn init(start_line: usize, start_column: usize, end_line: usize, end_column: usize) Self {
    return Self{
        .start = LineColumn{
            .line = start_line,
            .column = start_column,
        },
        .end = LineColumn{
            .line = end_line,
            .column = end_column,
        },
    };
}

pub fn extend_to_right(self: *Self, other: Self) void {
    if (self.start.line < other.start.line or self.start.column < other.start.column)
        self.start = other.start;
}

pub fn extend_to_left(self: *Self, other: Self) void {
    if (self.end.line < other.end.line or self.end.column < other.end.column)
        self.end = other.end;
}
