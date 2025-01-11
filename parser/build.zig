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

    // TESTS
    const test_step = b.step("test", "Perform all tests");
    const main_tests = b.addTest(.{
        .name = "parser-tests",
        .root_source_file = entry_file,
        .target = target,
        .optimize = optimize,
        .version = version,
    });

    const tests = b.addInstallArtifact(main_tests, .{});
    test_step.dependOn(&b.addRunArtifact(tests.artifact).step);
}
