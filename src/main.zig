// Override std.log with our custom logging function
pub const std_options: std.Options = .{
    .logFn = logging.logFn,
};

// Version should match build.zig.zon - CI will verify they're in sync
const version = "0.0.2";

var config = CliConfig{};

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
                .{
                    .long_name = "log-file",
                    .help = "path to debug log file (enables debug logging)",
                    .value_ref = r.mkRef(&config.log_file),
                },
                .{
                    .long_name = "indent-style",
                    .help = "indentation style: 'tabs', 'spaces'. Will auto detect if not specified.",
                    .value_ref = r.mkRef(&config.indent_type),
                },
                .{
                    .long_name = "indent-width",
                    .help = "indentation width (number of spaces, default: 4)",
                    .value_ref = r.mkRef(&config.indent_width),
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
    // Initialize logging system
    try logging.init(config.allocator, config.log_file, .{ .truncate = true });
    defer logging.deinit();

    if (config.version) {
        try logging.printMessageAndExit("gd-pretty {s}\n", .{version});
    }

    std.log.info("gd-pretty {s} starting", .{version});
    std.log.debug("Processing {} files", .{config.files.len});

    // Handle positional arguments - zig-cli should populate config.files
    if (config.files.len == 0) {
        try logging.printErrorAndExit(
            "Error: no files provided\n\nUSAGE: gd-pretty [OPTIONS] <files...>\n\nRun 'gd-pretty --help' for more information.\n",
            .{},
        );
    }

    const ts_parser = TSParser.init();
    defer ts_parser.deinit();

    const ts_gdscript = tree_sitter_gdscript();
    const success = ts_parser.setLanguage(@ptrCast(ts_gdscript));
    if (!success) {
        try logging.printErrorAndExit("Error: failed to load GDScript grammar\n", .{});
    }

    var arena = std.heap.ArenaAllocator.init(config.allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    var stdout_file = std.fs.File.stdout();
    defer stdout_file.close();

    var buf: [1024]u8 = undefined;
    var stdout_writer = stdout_file.writer(&buf);
    const writer = &stdout_writer.interface;

    const cli_whitespace_config: ?WhitespaceConfig = WhitespaceConfig.fromCli(config);

    for (config.files) |path| {
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            try logging.printErrorAndExit("Error: failed to open file '{s}': {}\n", .{ path, err });
        };
        defer file.close();

        const whitespace_config = cli_whitespace_config orelse try WhitespaceConfig.fromSourceFile(file);

        // Reset file position for parsing
        try file.seekTo(0);

        var tree = ts_parser.parseFile(arena_allocator, file) catch |err| {
            try logging.printErrorAndExit("Error: failed to parse file '{s}': {}\n", .{ path, err });
        };
        defer tree.deinit();

        const root_node = tree.rootNode();
        var cursor = root_node.cursor();

        var gd_writer = GdWriter.init(.{
            .writer = writer,
            .allocator = arena_allocator,
            .whitespace_config = whitespace_config,
        });

        formatter.depthFirstWalk(&cursor, &gd_writer) catch |err| {
            try logging.printErrorAndExit("Error: failed to format file '{s}': {}\n", .{ path, err });
        };
        try writer.writeByte('\n');
        try writer.flush();
    }
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

    var desired_match_count: u32 = 0;
    var desired_total_count: u32 = 0;

    var it = dir.iterateAssumeFirstIteration();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;

        if (std.mem.endsWith(u8, entry.name, ".in.gd")) {
            std.debug.print("Processing input file: {s}\n", .{entry.name});

            const in_file = try dir.openFile(entry.name, .{});
            defer in_file.close();

            var tree = try ts_parser.parseFile(allocator, in_file);
            var cursor = tree.rootNode().cursor();

            const base_name = entry.name[0 .. entry.name.len - 6];

            for ([_]IndentType{ .tabs, .spaces }) |indent_style| {
                const style_name = @tagName(indent_style);
                const out_file_name = try std.fmt.allocPrint(allocator, "{s}.{s}.gd", .{
                    base_name,
                    style_name,
                });

                // Write output file in a scope so it's closed before we re-read it
                {
                    var out_file = try dir.createFile(out_file_name, .{});
                    defer out_file.close();

                    var out_file_writer = out_file.writer(&buf);
                    const writer = &out_file_writer.interface;

                    var gd_writer: GdWriter = .init(.{
                        .writer = writer,
                        .allocator = allocator,
                        .whitespace_config = .{
                            .style = indent_style,
                        },
                    });

                    try formatter.depthFirstWalk(&cursor, &gd_writer);
                    try writer.flush();
                }

                // Compare with desired file if it exists
                const desired_file_name = try std.fmt.allocPrint(allocator, "{s}.desired.{s}.gd", .{
                    base_name,
                    style_name,
                });

                if (dir.openFile(desired_file_name, .{})) |desired_file| {
                    defer desired_file.close();
                    const desired_content = try desired_file.readToEndAlloc(allocator, 1024 * 1024);

                    const actual_file = try dir.openFile(out_file_name, .{});
                    defer actual_file.close();
                    const actual_content = try actual_file.readToEndAlloc(allocator, 1024 * 1024);

                    if (std.mem.eql(u8, desired_content, actual_content)) {
                        desired_match_count += 1;
                        std.debug.print("  DESIRED MATCH: {s}\n", .{desired_file_name});
                    } else {
                        std.debug.print("  DESIRED MISMATCH: {s}\n", .{desired_file_name});
                    }
                    desired_total_count += 1;
                } else |_| {}
            }
        }
    }

    if (desired_total_count > 0) {
        std.debug.print("\nDesired output progress: {}/{} matching\n", .{
            desired_match_count,
            desired_total_count,
        });
    }
}

const std = @import("std");
const ArenaAllocator = std.heap.ArenaAllocator;
const testing = std.testing;

const enums = @import("enums.zig");
const IndentType = enums.IndentType;

const ts = @import("tree-sitter");
const TSParser = ts.TSParser;

const cli = @import("cli");

const CliConfig = @import("CliConfig.zig");
const GdWriter = @import("GdWriter.zig");
const WhitespaceConfig = @import("WhitespaceConfig.zig");

const formatter = @import("formatter.zig");
const logging = @import("logging.zig");

extern fn tree_sitter_gdscript() ?*anyopaque;
