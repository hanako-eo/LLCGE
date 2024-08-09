const std = @import("std");

pub fn build(b: *std.Build) void {
    const std_target = b.standardTargetOptions(.{});
    const std_optimize = b.standardOptimizeOption(.{});

    //// BUILD LIB
    const lib = b.addStaticLibrary(.{
        .name = "LLCGE",
        .root_source_file = b.path("src/main.zig"),
        .target = std_target,
        .optimize = std_optimize,
    });

    b.installArtifact(lib);

    //// BUILD AND RUN TESTS
    const test_step = b.step("test", "Run library tests");

    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = std_target,
        .optimize = std_optimize,
    });

    const run_main_tests = b.addRunArtifact(main_tests);

    test_step.dependOn(&run_main_tests.step);
}
