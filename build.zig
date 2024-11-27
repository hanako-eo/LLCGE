const builtin = @import("builtin");
const std = @import("std");

const utils = @import("./common_utils.zig");

pub const min_zig_version = std.SemanticVersion{
    .major = 0,
    .minor = 14,
    .patch = 0,
    .pre = "-dev.1671",
};

const Packages = struct {
    pub const diagnostic = @import("./diagnostic/build.zig");
    pub const llcge = @import("./llcge/build.zig");
};

pub fn build(b: *std.Build) void {
    ensureZigVersion() catch return;

    const compile_exclude_list = b.option([]const []const u8, "exclude", "Exclude of the compile the provided list of libs. (cannot be used with -Donly)");
    const compile_only_list = b.option([]const []const u8, "only", "Compile only the provided list of libs. (cannot be used with -Dexclude)");

    const compile_list = CompileList.init(compile_exclude_list, compile_only_list) orelse {
        std.log.err("\n" ++
            \\---------------------------------------------------------------------------
            \\
            \\You cannot give an exclude list and an include list of libs to compile at the same time.
            \\
            \\Please try again by removing -Donly or -Dexclude.
            \\
            \\---------------------------------------------------------------------------
            \\
        , .{});
        return;
    };

    const static_list = b.option([]const []const u8, "static", "Compile all libs provided in a list of -Dstatic, to compile all in static use -Dstatic-all.");
    const static_all = b.option(bool, "static-all", "Compile all libs into static libs or if you want only a part of the list to be compile in static use -Dstatic.");

    const static_option = utils.StaticOption.init(static_all orelse false, static_list);

    const test_step = b.step("test", "Perform all tests.");

    var b2 = utils.Build{
        .build = b,
        .static_option = static_option,
        .test_step = test_step,
        .package_name = "",
    };

    inline for (comptime std.meta.declarations(Packages)) |decl| {
        if (compile_list.can_compile(decl.name)) {
            const lib = @field(Packages, decl.name);

            b2.package_name = decl.name;
            b2.print_step(&lib.version);
            lib.build(&b2);
        }
    }
}

fn ensureZigVersion() !void {
    var installed_ver = builtin.zig_version;
    installed_ver.build = null;

    if (installed_ver.order(min_zig_version) == .lt) {
        std.log.err("\n" ++
            \\---------------------------------------------------------------------------
            \\
            \\Installed Zig compiler version is too old.
            \\
            \\Min. required version: {any}
            \\Installed version: {any}
            \\
            \\Please install newer version and try again.
            \\Latest version can be found here: https://ziglang.org/download/
            \\
            \\---------------------------------------------------------------------------
            \\
        , .{ min_zig_version, installed_ver });
        return error.ZigIsTooOld;
    }
}

pub const CompileList = union(enum) {
    excludes: []const []const u8,
    includes: []const []const u8,
    no_restriction: void,

    const Self = @This();
    fn init(excludes: ?[]const []const u8, includes: ?[]const []const u8) ?Self {
        if (excludes != null and includes != null) return null;

        return if (excludes) |list| Self{ .excludes = list } else if (includes) |list| Self{ .includes = list } else Self.no_restriction;
    }

    fn can_compile(self: Self, name: []const u8) bool {
        return switch (self) {
            .excludes => |list| !utils.array_contain_string(list, name),
            .includes => |list| utils.array_contain_string(list, name),
            .no_restriction => true,
        };
    }
};
