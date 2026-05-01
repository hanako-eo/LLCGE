const std = @import("std");
const build_zon = @import("./build.zig.zon");

pub fn build(b: *std.Build) !void {
    const version = try std.SemanticVersion.parse(build_zon.version);

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.addModule("parser", .{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    add_dependencies(module, &.{
        .{
            "utils", b.dependency("utils", .{
                .target = target,
                .optimize = optimize,
            }),
        },
    });
    add_dependencies(module, &dependencies);

    const artifact_lib = b.addLibrary(.{
        .name = "parser",
        .root_module = module,
        .version = version,
    });
    b.installArtifact(artifact_lib);

    // TESTS
    const test_step = b.step("test", "Perform all tests");
    const main_tests = b.addTest(.{
        .name = "parser-tests",
        .root_module = module,
    });

    const tests = b.addInstallArtifact(main_tests, .{});
    test_step.dependOn(&b.addRunArtifact(tests.artifact).step);
}

fn add_dependencies(module: *std.Build.Module, dependencies: []const struct { []const u8, *std.Build.Dependency }) void {
    for (dependencies) |dependency| {
        module.addImport(dependency.@"0", dependency.@"1".module(dependency.@"0"));
    }
}
