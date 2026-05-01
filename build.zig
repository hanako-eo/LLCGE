const std = @import("std");
const build_zon = @import("./build.zig.zon");

pub fn build(b: *std.Build) !void {
    const linkmode = b.option(std.builtin.LinkMode, "linkage", "Force the compilation to compile all into static or dynamic library") orelse .dynamic;
    const version = try std.SemanticVersion.parse(build_zon.version);

    const test_step = b.step("test", "Perform all tests");

    inline for (@typeInfo(@TypeOf(build_zon.workspace)).@"struct".fields) |field| {
        if (!@hasField(@TypeOf(build_zon.dependencies), field.name))
            continue;

        const overrided_options = @field(build_zon.workspace, field.name);
        const submodule = b.dependency(field.name, overrided_options).module(field.name);

        const lib = b.addLibrary(.{
            .name = field.name,
            .linkage = linkmode,
            .version = version,
            .root_module = submodule,
        });

        b.installArtifact(lib);

        // TESTS
        const lib_tests = b.addTest(.{
            .name = field.name ++ "-tests",
            .root_module = submodule,
        });

        const tests = b.addInstallArtifact(lib_tests, .{});
        test_step.dependOn(&b.addRunArtifact(tests.artifact).step);
    }
}
