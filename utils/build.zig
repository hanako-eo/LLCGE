const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.addModule("utils", .{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    // TESTS
    const test_step = b.step("test", "Perform all tests");
    const main_tests = b.addTest(.{
        .name = "utils-tests",
        .root_module = module,
    });

    const tests = b.addInstallArtifact(main_tests, .{});
    test_step.dependOn(&b.addRunArtifact(tests.artifact).step);
}
