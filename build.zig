const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const diff = b.addSystemCommand(&.{
        "git",
        "diff",
        "--cached", // see git_add comment
        "--exit-code",
    });

    const tests_path = b.path("tests/");

    diff.addDirectoryArg(tests_path);

    const git_add = b.addSystemCommand(&.{
        "git",
        "add",
    });

    git_add.addDirectoryArg(tests_path);

    diff.step.dependOn(&git_add.step);

    const mod_exe = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "gd-pretty",
        .root_module = mod_exe,
    });

    const lib_ts_c = b.dependency("tree_sitter", .{
        .target = target,
        .optimize = optimize,
    });
    const ts_c_include_path = lib_ts_c.path("lib/include");

    const dep_ts_gd = b.dependency("tree_sitter_gdscript", .{});

    const translate_ts_c = b.addTranslateC(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = ts_c_include_path.path(b, "tree_sitter/api.h"),
    });

    const mod_ts_c = b.createModule(.{
        .root_source_file = translate_ts_c.getOutput(),
        .target = target,
        .optimize = optimize,
    });

    const mod_ts = b.createModule(.{
        .root_source_file = b.path("lib/tree-sitter/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    mod_ts.addImport("tree-sitter-c", mod_ts_c);

    const mod_ts_gd = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    mod_ts_gd.addCSourceFiles(.{
        .root = dep_ts_gd.builder.path("src"),
        .files = &.{
            "parser.c",
            "scanner.c",
        },
    });
    mod_ts_gd.addIncludePath(lib_ts_c.builder.path("lib/include"));
    mod_ts_gd.addIncludePath(dep_ts_gd.builder.path("src"));

    const lib_ts_gd = b.addLibrary(.{
        .name = "tree-sitter-gdscript",
        .root_module = mod_ts_gd,
    });

    mod_exe.addImport("tree-sitter", mod_ts);
    mod_exe.addImport("tree-sitter-gdscript", mod_ts_gd);

    exe.linkLibrary(lib_ts_c.artifact("tree-sitter"));
    exe.linkLibrary(lib_ts_gd);

    // Case module
    const dep_case = b.dependency("case", .{});
    const mod_case = b.createModule(.{
        .root_source_file = dep_case.builder.path("src/lib.zig"),
    });
    mod_exe.addImport("case", mod_case);

    // CLI module
    const cli_dep = b.dependency("cli", .{});
    const cli_mod = cli_dep.module("cli");
    mod_exe.addImport("cli", cli_mod);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = mod_exe,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
    test_step.dependOn(&diff.step);
}
