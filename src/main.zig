const std = @import("std");
const ts = @import("tree-sitter");
const gd = @import("tree-sitter-gdscript");
const cli = @import("cli");

const TSParser = ts.TSParser;
const Context = @import("Context.zig");
const enums = @import("enums.zig");
const formatter = @import("formatter.zig");
const statements = @import("statements.zig");

const GdNodeType = enums.GdNodeType;

// Version should match build.zig.zon - CI will verify they're in sync
const version = "0.0.1";

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
        const stdout = std.io.getStdOut().writer();
        try stdout.print("gd-pretty {s}\n", .{version});
        return;
    }

    // Handle positional arguments - zig-cli should populate config.files
    if (config.files.len == 0) {
        const stderr = std.io.getStdErr().writer();
        try stderr.print("Error: no files provided\n\nUSAGE: gd-pretty [OPTIONS] <files...>\n\nRun 'gd-pretty --help' for more information.\n", .{});
        std.process.exit(1);
    }

    const ts_parser = TSParser.init();
    defer ts_parser.deinit();

    const ts_gdscript = gd.tree_sitter_gdscript();
    const success = ts_parser.setLanguage(@ptrCast(ts_gdscript));
    if (!success) {
        const stderr = std.io.getStdErr().writer();
        try stderr.print("Error: failed to load GDScript grammar\n", .{});
        std.process.exit(1);
    }

    var arena = std.heap.ArenaAllocator.init(config.allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    var stdout = std.io.getStdOut();
    const stdout_writer = stdout.writer();

    var buffered_writer = std.io.bufferedWriter(stdout_writer);
    const br = buffered_writer.writer();
    defer buffered_writer.flush() catch {};

    var counting_writer = std.io.countingWriter(br);
    const writer = counting_writer.writer().any();

    for (config.files) |path| {
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            const stderr = std.io.getStdErr().writer();
            try stderr.print("Error: failed to open file '{s}': {}\n", .{ path, err });
            std.process.exit(1);
        };
        defer file.close();

        const buf = arena_allocator.alloc(u8, file.getEndPos() catch |err| {
            const stderr = std.io.getStdErr().writer();
            try stderr.print("Error: failed to read file '{s}': {}\n", .{ path, err });
            std.process.exit(1);
        }) catch |err| {
            const stderr = std.io.getStdErr().writer();
            try stderr.print("Error: failed to allocate memory for file '{s}': {}\n", .{ path, err });
            std.process.exit(1);
        };

        _ = file.readAll(buf) catch |err| {
            const stderr = std.io.getStdErr().writer();
            try stderr.print("Error: failed to read file '{s}': {}\n", .{ path, err });
            std.process.exit(1);
        };

        var tree = ts_parser.parseString(buf) catch |err| {
            const stderr = std.io.getStdErr().writer();
            try stderr.print("Error: failed to parse file '{s}': {}\n", .{ path, err });
            std.process.exit(1);
        };
        defer tree.deinit();

        const root_node = tree.rootNode();
        var cursor = root_node.cursor();

        formatter.depthFirstWalk(&cursor, writer, .{}) catch |err| {
            const stderr = std.io.getStdErr().writer();
            try stderr.print("Error: failed to format file '{s}': {}\n", .{ path, err });
            std.process.exit(1);
        };
    }
}

test "input output pairs" {
    const ts_parser = TSParser.init();
    defer ts_parser.deinit();

    const ts_gdscript = gd.tree_sitter_gdscript();
    _ = ts_parser.setLanguage(@ptrCast(ts_gdscript));

    var dir = try std.fs.cwd().openDir("tests/input-output-pairs", .{
        .iterate = true,
    });
    defer dir.close();

    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

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

            const buffer = try allocator.alloc(u8, try in_file.getEndPos());
            _ = try in_file.readAll(buffer);

            var tree = try ts_parser.parseString(buffer);
            var cursor = tree.rootNode().cursor();

            try formatter.depthFirstWalk(&cursor, out_file.writer().any(), .{});
        }
    }
}

const ArenaAllocator = std.heap.ArenaAllocator;
const testing = std.testing;
