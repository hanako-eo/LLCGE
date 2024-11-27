const std = @import("std");

const utils = @import("../common_utils.zig");

pub const version = std.SemanticVersion{
    .major = 0,
    .minor = 1,
    .patch = 0,
    .pre = "alpha",
};

pub fn build(b: *utils.Build) void {
    const target = b.standard_target_options(.{ });
    const optimize = b.standard_optimize_option(.{ });

    const entry_file = b.path("src/lib.zig");

    _ = b.add_module("llcge", .{
        .root_source_file = entry_file,
        .target = target,
        .optimize = optimize,
    });

    const artifact_lib = b.add_library(.{
        .name = "llcge",
        .root_source_file = entry_file,
        .target = target,
        .optimize = optimize,
        .version = version,
    });
    b.install_artifact(artifact_lib);

    b.add_test(.{
        .name = "llcge-tests",
        .root_source_file = entry_file,
        .target = target,
        .optimize = optimize,
        .version = version,
    });
}

// pub fn build(b: *std.Build) void {
//     const std_target = b.standardTargetOptions(.{});
//     const std_optimize = b.standardOptimizeOption(.{});

//     const root_file = b.path("src/lib.zig");

//     //// BUILD LIB
//     _ = b.addModule("llcge", .{ .root_source_file = root_file });

//     const lib = b.addStaticLibrary(.{
//         .name = "llcge",
//         .root_source_file = root_file,
//         .target = std_target,
//         .optimize = std_optimize,
//         .version = version,
//     });

//     b.installArtifact(lib);

//     //// BUILD AND RUN TESTS
//     const test_step = b.step("test", "Run library tests");

//     const main_tests = b.addTest(.{
//         .name = "llcge-tests",
//         .root_source_file = root_file,
//         .target = std_target,
//         .optimize = std_optimize,
//     });

//     const tests = b.addInstallArtifact(main_tests, .{});
//     test_step.dependOn(&b.addRunArtifact(tests.artifact).step);
// }
