const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const entry_file = b.path("tools/lib.zig");

    const dependencies = [_]struct { []const u8, *std.Build.Dependency }{ .{
        "parser", b.dependency("parser", .{
            .target = target,
            .optimize = optimize,
        }),
    }, .{ "yazap", b.dependency("yazap", .{}) } };

    const exe = b.addExecutable(.{
        .name = "build-tools",
        .root_source_file = entry_file,
        .target = target,
        .optimize = optimize,
    });

    add_dependencies(exe.root_module, &dependencies);
    const exe_run = b.addRunArtifact(exe);
    if (b.args) |args| {
        exe_run.addArgs(args);
    }
    b.default_step.dependOn(&exe_run.step);
}

fn add_dependencies(module: *std.Build.Module, dependencies: []const struct { []const u8, *std.Build.Dependency }) void {
    for (dependencies) |dependency| {
        module.addImport(dependency.@"0", dependency.@"1".module(dependency.@"0"));
    }
}
