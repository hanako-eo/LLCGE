const std = @import("std");
const yazap = @import("yazap");

const commands = .{
    .release = @import("./release.zig"),
};

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var app = yazap.App.init(allocator, "zig build --", null);
    defer app.deinit();

    var root_command = app.rootCommand();
    root_command.setProperty(.help_on_empty_args);

    inline for (@typeInfo(@TypeOf(commands)).@"struct".fields) |field| {
        const file_command = @field(commands, field.name);
        check_command(field.name, file_command);

        var command = app.createCommand(field.name, file_command.description);
        file_command.init(&command);
        try root_command.addSubcommand(command);
    }

    const matches = try app.parseProcess();
    inline for (@typeInfo(@TypeOf(commands)).@"struct".fields) |field| {
        const file_command = @field(commands, field.name);

        if (matches.subcommandMatches(field.name)) |_| {
            file_command.main(allocator);
        }
    }

    std.debug.print("Hello !\n", .{});
}

fn check_command(comptime name: []const u8, comptime CommandType: anytype) void {
    if (!@hasDecl(CommandType, "description"))
        @compileError(std.fmt.comptimePrint("the command {s} must have a description constant.", .{name}));

    if (!@hasDecl(CommandType, "init"))
        @compileError(std.fmt.comptimePrint("the command {s} must have a init function.", .{name}));

    if (!@hasDecl(CommandType, "main"))
        @compileError(std.fmt.comptimePrint("the command {s} must have a main function.", .{name}));
}
