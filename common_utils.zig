const std = @import("std");

pub fn array_contain_string(array: []const []const u8, string: []const u8) bool {
    for (array) |el| {
        if (std.mem.eql(u8, el, string))
            return true;
    }
    return false;
}

pub const Build = struct {
    build: *std.Build,
    test_step: *std.Build.Step,

    package_name: []const u8,
    static_option: StaticOption,

    target: ?std.Build.ResolvedTarget = null,
    optimize: ?std.builtin.OptimizeMode = null,

    pub const LibraryOptions = struct {
        name: []const u8,
        /// To choose the same computer as the one building the package, pass the
        /// `host` field of the package's `Build` instance.
        target: std.Build.ResolvedTarget,
        optimize: std.builtin.OptimizeMode,
        code_model: std.builtin.CodeModel = .default,
        root_source_file: ?std.Build.LazyPath = null,
        version: ?std.SemanticVersion = null,
        max_rss: usize = 0,
        link_libc: ?bool = null,
        single_threaded: ?bool = null,
        pic: ?bool = null,
        strip: ?bool = null,
        unwind_tables: ?bool = null,
        omit_frame_pointer: ?bool = null,
        sanitize_thread: ?bool = null,
        error_tracing: ?bool = null,
        use_llvm: ?bool = null,
        use_lld: ?bool = null,
        zig_lib_dir: ?std.Build.LazyPath = null,
    };

    const Self = @This();
    pub fn add_module(self: *Self, name: []const u8, options: std.Build.Module.CreateOptions) *std.Build.Module {
        return self.build.addModule(name, options);
    }

    pub fn add_library(self: *Self, options: LibraryOptions) *std.Build.Step.Compile {
        if (self.build_in_static()) {
            return self.add_static_library(.{
                .name = options.name,
                .target = options.target,
                .optimize = options.optimize,
                .code_model = options.code_model,
                .root_source_file = options.root_source_file,
                .version = options.version,
                .max_rss = options.max_rss,
                .link_libc = options.link_libc,
                .single_threaded = options.single_threaded,
                .pic = options.pic,
                .strip = options.strip,
                .unwind_tables = options.unwind_tables,
                .omit_frame_pointer = options.omit_frame_pointer,
                .sanitize_thread = options.sanitize_thread,
                .error_tracing = options.error_tracing,
                .use_llvm = options.use_llvm,
                .use_lld = options.use_lld,
                .zig_lib_dir = options.zig_lib_dir,
            });
        } else {
            return self.add_shared_library(.{
                .name = options.name,
                .target = options.target,
                .optimize = options.optimize,
                .code_model = options.code_model,
                .root_source_file = options.root_source_file,
                .version = options.version,
                .max_rss = options.max_rss,
                .link_libc = options.link_libc,
                .single_threaded = options.single_threaded,
                .pic = options.pic,
                .strip = options.strip,
                .unwind_tables = options.unwind_tables,
                .omit_frame_pointer = options.omit_frame_pointer,
                .sanitize_thread = options.sanitize_thread,
                .error_tracing = options.error_tracing,
                .use_llvm = options.use_llvm,
                .use_lld = options.use_lld,
                .zig_lib_dir = options.zig_lib_dir,
            });
        }
    }

    pub fn add_static_library(self: *Self, options: std.Build.StaticLibraryOptions) *std.Build.Step.Compile {
        return self.build.addStaticLibrary(options);
    }

    pub fn add_shared_library(self: *Self, options: std.Build.SharedLibraryOptions) *std.Build.Step.Compile {
        return self.build.addSharedLibrary(options);
    }

    pub fn add_test(self: *Self, options: std.Build.TestOptions) void {
        const main_tests = self.build.addTest(options);

        const tests = self.build.addInstallArtifact(main_tests, .{});
        self.test_step.dependOn(&self.build.addRunArtifact(tests.artifact).step);
    }

    pub fn build_in_static(self: *Self) bool {
        return self.static_option.is_static(self.package_name);
    }

    pub fn install_artifact(self: *Self, artifact: *std.Build.Step.Compile) void {
        self.build.installArtifact(artifact);
    }

    pub fn path(self: *Self, sub_path: []const u8) std.Build.LazyPath {
        return self.build.path(self.build.pathJoin(&.{ self.package_name, sub_path }));
    }

    pub fn print_step(self: *Self, version: *const std.SemanticVersion) void {
        if (!self.build.verbose) return;

        const target = self.standard_target_options(.{  });
        const optimize = self.standard_optimize_option(.{  });

        std.debug.print(
            \\---------------------------------------------------------------------------
            \\Compilation of '{s}':
            \\  - version: {}
            \\  - static: {}
            \\  - target: {s}-{s}-{s}
            \\  - optimization: {s}
            \\
        , .{
            self.package_name,
            version,
            self.build_in_static(),
            @tagName(target.result.cpu.arch), @tagName(target.result.os.tag), @tagName(target.result.abi),
            @tagName(optimize)
        });
    }

    pub fn standard_target_options(self: *Self, args: std.Build.StandardTargetOptionsArgs) std.Build.ResolvedTarget {
        if (self.target == null) {
            self.target = self.build.standardTargetOptions(args);
        }
        return self.target.?;
    }
    pub fn standard_optimize_option(self: *Self, options: std.Build.StandardOptimizeOptionOptions) std.builtin.OptimizeMode {
        if (self.optimize == null) {
            self.optimize = self.build.standardOptimizeOption(options);
        }
        return self.optimize.?;
    }
};

pub const StaticOption = union(enum) {
    list: []const []const u8,
    nothing: void,
    all: void,

    const Self = @This();
    pub fn init(all: bool, static_list: ?[]const []const u8) Self {
        return if (all) Self.all
            else if (static_list) |list| Self { .list = list }
            else Self.nothing;
    }

    pub fn is_static(self: Self, name: []const u8) bool {
        return switch (self) {
            .list => |list| array_contain_string(list, name),
            .nothing => false,
            .all => true,
        };
    }
};
