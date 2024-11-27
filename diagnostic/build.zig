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

    _ = b.add_module("diagnostic", .{
        .root_source_file = entry_file,
        .target = target,
        .optimize = optimize,
    });

    const artifact_lib = b.add_library(.{
        .name = "diagnostic",
        .root_source_file = entry_file,
        .target = target,
        .optimize = optimize,
        .version = version,
    });
    b.install_artifact(artifact_lib);

    b.add_test(.{
        .name = "diagnostic-tests",
        .root_source_file = entry_file,
        .target = target,
        .optimize = optimize,
        .version = version,
    });
}
