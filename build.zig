const std = @import("std");

const version = std.SemanticVersion {
    .major = 0,
    .minor = 1,
    .patch = 0,
    .pre = "alpha",
};

pub fn build(b: *std.Build) void {
    const std_target = b.standardTargetOptions(.{});
    const std_optimize = b.standardOptimizeOption(.{});

    const root_file = b.path("src/lib.zig");

    //// BUILD LIB
    _ = b.addModule("llcge", .{ .root_source_file = root_file });

    const lib = b.addStaticLibrary(.{
        .name = "LLCGE",
        .root_source_file = root_file,
        .target = std_target,
        .optimize = std_optimize,
        .version = version,
    });

    b.installArtifact(lib);

    //// BUILD AND RUN TESTS
    const test_step = b.step("test", "Run library tests");

    const main_tests = b.addTest(.{
        .root_source_file = root_file,
        .target = std_target,
        .optimize = std_optimize,
    });

    const run_main_tests = b.addRunArtifact(main_tests);

    test_step.dependOn(&run_main_tests.step);
}
