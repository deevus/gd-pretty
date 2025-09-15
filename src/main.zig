const std = @import("std");
const ts = @import("tree-sitter");
const cli = @import("cli");

const TSParser = ts.TSParser;
const Context = @import("Context.zig");
const enums = @import("enums.zig");
const formatter = @import("formatter.zig");

const GdNodeType = enums.GdNodeType;

// Version should match build.zig.zon - CI will verify they're in sync
const version = "0.0.2";

var config = struct {
    files: []const []const u8 = &.{},
    version: bool = false,
    allocator: std.mem.Allocator = undefined,
}{};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // Store allocator in config for formatFiles
    config.allocator = gpa.allocator();

    // Use arena allocator for CLI parsing to avoid leaks
    var cli_arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer cli_arena.deinit();
    const cli_allocator = cli_arena.allocator();

    var r = try cli.AppRunner.init(cli_allocator);

    const app = cli.App{
        .command = cli.Command{
            .name = "gd-pretty",
            .description = .{
                .one_line = "A GDScript code formatter",
                .detailed = "Formats GDScript files to ensure consistent code style using tree-sitter for parsing.",
            },
            .options = try r.allocOptions(&.{
                .{
                    .long_name = "version",
                    .short_alias = 'v',
                    .help = "show version information",
                    .value_ref = r.mkRef(&config.version),
                },
            }),
            .target = cli.CommandTarget{
                .action = cli.CommandAction{ .positional_args = cli.PositionalArgs{
                    .optional = try r.allocPositionalArgs(&.{
                        .{
                            .name = "files",
                            .help = "GDScript files to format",
                            .value_ref = r.mkRef(&config.files),
                        },
                    }),
                }, .exec = formatFiles },
            },
        },
        .version = version,
    };

    return r.run(&app);
}

fn formatFiles() !void {
    if (config.version) {
        try printMessageAndExit("gd-pretty {s}\n", .{version});
    }

    // Handle positional arguments - zig-cli should populate config.files
    if (config.files.len == 0) {
        try printErrorAndExit(
            "Error: no files provided\n\nUSAGE: gd-pretty [OPTIONS] <files...>\n\nRun 'gd-pretty --help' for more information.\n",
            .{},
        );
    }

    const ts_parser = TSParser.init();
    defer ts_parser.deinit();

    const ts_gdscript = tree_sitter_gdscript();
    const success = ts_parser.setLanguage(@ptrCast(ts_gdscript));
    if (!success) {
        try printErrorAndExit("Error: failed to load GDScript grammar\n", .{});
    }

    var arena = std.heap.ArenaAllocator.init(config.allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    var stdout_file = std.fs.File.stdout();
    defer stdout_file.close();

    var buf: [1024]u8 = undefined;
    var stdout_writer = stdout_file.writer(&buf);
    const writer = &stdout_writer.interface;

    for (config.files) |path| {
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            try printErrorAndExit("Error: failed to open file '{s}': {}\n", .{ path, err });
        };
        defer file.close();

        var tree = ts_parser.parseFile(arena_allocator, file) catch |err| {
            try printErrorAndExit("Error: failed to parse file '{s}': {}\n", .{ path, err });
        };
        defer tree.deinit();

        const root_node = tree.rootNode();
        var cursor = root_node.cursor();

        formatter.depthFirstWalk(&cursor, writer, .{}) catch |err| {
            try printErrorAndExit("Error: failed to format file '{s}': {}\n", .{ path, err });
        };
    }
}

fn printMessageAndExit(comptime fmt: []const u8, args: anytype) !noreturn {
    var stdout_file = std.fs.File.stdout();
    defer stdout_file.close();

    var buf: [128]u8 = undefined;
    var stdout_writer = stdout_file.writer(&buf);
    var w = &stdout_writer.interface;
    try w.print(fmt, args);
    try w.flush();

    std.process.exit(0);
}

fn printErrorAndExit(comptime fmt: []const u8, args: anytype) !noreturn {
    var stderr_file = std.fs.File.stderr();
    defer stderr_file.close();

    var buf: [128]u8 = undefined;
    var stderr_writer = stderr_file.writer(&buf);
    var w = &stderr_writer.interface;
    try w.print(fmt, args);
    try w.flush();

    std.process.exit(1);
}

test "input output pairs" {
    const ts_parser = TSParser.init();
    defer ts_parser.deinit();

    const ts_gdscript = tree_sitter_gdscript();
    _ = ts_parser.setLanguage(@ptrCast(ts_gdscript));

    var dir = try std.fs.cwd().openDir("tests/input-output-pairs", .{
        .iterate = true,
    });
    defer dir.close();

    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var buf: [1024]u8 = undefined;

    var it = dir.iterateAssumeFirstIteration();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;

        if (std.mem.endsWith(u8, entry.name, ".in.gd")) {
            const in_file = try dir.openFile(entry.name, .{});
            defer in_file.close();

            const out_file_name = try std.fmt.allocPrint(allocator, "{s}.out.gd", .{
                entry.name[0 .. entry.name.len - 6],
            });
            var out_file = try dir.createFile(out_file_name, .{});
            defer out_file.close();

            var out_file_writer = out_file.writer(&buf);
            const writer = &out_file_writer.interface;

            var tree = try ts_parser.parseFile(allocator, in_file);
            var cursor = tree.rootNode().cursor();

            try formatter.depthFirstWalk(&cursor, writer, .{});
            try writer.flush();
        }
    }
}

const ArenaAllocator = std.heap.ArenaAllocator;
const testing = std.testing;

extern fn tree_sitter_gdscript() ?*anyopaque;
