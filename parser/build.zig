const std = @import("std");

pub const version = std.SemanticVersion{
    .major = 0,
    .minor = 1,
    .patch = 0,
    .pre = "alpha",
};

pub fn build(b: *std.Build) void {
    const static = b.option(bool, "static", "Build into static") orelse false;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const entry_file = b.path("src/lib.zig");

    const dependencies = [_]struct { []const u8, *std.Build.Dependency }{
        .{
            "utils", b.dependency("utils", .{
                .target = target,
                .optimize = optimize,
            }),
        },
    };

    _ = b.addModule("parser", .{
        .root_source_file = entry_file,
        .target = target,
        .optimize = optimize,
    });

    const artifact_lib = if (static) b.addStaticLibrary(.{
        .name = "parser",
        .root_source_file = entry_file,
        .target = target,
        .optimize = optimize,
        .version = version,
    }) else b.addSharedLibrary(.{
        .name = "parser",
        .root_source_file = entry_file,
        .target = target,
        .optimize = optimize,
        .version = version,
    });
    b.installArtifact(artifact_lib);
    add_dependencies(artifact_lib.root_module, &dependencies);

    // TESTS
    const test_step = b.step("test", "Perform all tests");
    const main_tests = b.addTest(.{
        .name = "parser-tests",
        .root_source_file = entry_file,
        .target = target,
        .optimize = optimize,
        .version = version,
    });
    add_dependencies(main_tests.root_module, &dependencies);

    const tests = b.addInstallArtifact(main_tests, .{});
    test_step.dependOn(&b.addRunArtifact(tests.artifact).step);
}

fn add_dependencies(module: *std.Build.Module, dependencies: []const struct { []const u8, *std.Build.Dependency }) void {
    for (dependencies) |dependency| {
        module.addImport(dependency.@"0", dependency.@"1".module(dependency.@"0"));
    }
}
