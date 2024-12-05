const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const entry_file = b.path("src/lib.zig");

    _ = b.addModule("utils", .{
        .root_source_file = entry_file,
        .target = target,
        .optimize = optimize,
    });

    // TESTS
    const test_step = b.step("test", "Perform all tests");
    const main_tests = b.addTest(.{
        .name = "utils-tests",
        .root_source_file = entry_file,
        .target = target,
        .optimize = optimize,
    });

    const tests = b.addInstallArtifact(main_tests, .{});
    test_step.dependOn(&b.addRunArtifact(tests.artifact).step);
}
