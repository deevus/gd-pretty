const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "gd-pretty",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tree_sitter_lib = b.dependency("tree_sitter", .{
        .target = target,
        .optimize = optimize,
    });
    const tree_sitter_include_path = tree_sitter_lib.path("lib/include");

    const tree_sitter_module = b.createModule(.{
        .root_source_file = b.path("lib/tree-sitter/root.zig"),
    });
    tree_sitter_module.addIncludePath(tree_sitter_include_path);

    exe.linkLibrary(tree_sitter_lib.artifact("tree-sitter"));
    exe.root_module.addImport("tree-sitter", tree_sitter_module);

    const dep_tree_sitter_gdscript = b.dependency("tree_sitter_gdscript", .{});

    const lib_tree_sitter_gdscript = b.addStaticLibrary(.{
        .name = "tree-sitter-gdscript",
        .target = target,
        .optimize = optimize,
    });

    lib_tree_sitter_gdscript.addCSourceFiles(.{
        .files = &[_][]const u8{
            "parser.c",
            "scanner.c",
        },
        .root = dep_tree_sitter_gdscript.builder.path("src"),
    });
    lib_tree_sitter_gdscript.linkLibC();
    lib_tree_sitter_gdscript.addIncludePath(tree_sitter_lib.path("lib/include"));
    lib_tree_sitter_gdscript.addIncludePath(dep_tree_sitter_gdscript.builder.path("src"));

    const tree_sitter_gdscript_module = b.createModule(.{
        .root_source_file = b.path("lib/lib-tree-sitter-gdscript.zig"),
    });
    tree_sitter_gdscript_module.addIncludePath(dep_tree_sitter_gdscript.builder.path("bindings/swift/"));

    exe.linkLibrary(lib_tree_sitter_gdscript);
    exe.root_module.addImport("tree-sitter-gdscript", tree_sitter_gdscript_module);

    b.installArtifact(lib_tree_sitter_gdscript);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
