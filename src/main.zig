const std = @import("std");
const ts = @import("tree-sitter");
const cli = @import("cli");

const TSParser = ts.TSParser;
const Context = @import("Context.zig");
const IndentConfig = @import("IndentConfig.zig");
const enums = @import("enums.zig");
const formatter = @import("formatter.zig");
const logging = @import("logging.zig");

// Override std.log with our custom logging function
pub const std_options: std.Options = .{
    .logFn = logging.logFn,
};

const GdNodeType = enums.GdNodeType;
const IndentType = enums.IndentType;

// Version should match build.zig.zon - CI will verify they're in sync
const version = "0.0.2";

var config = struct {
    files: []const []const u8 = &.{},
    version: bool = false,
    log_file: ?[]const u8 = null,
    indent_style: ?[]const u8 = null,
    indent_width: u32 = 4,
    auto_detect_indent: bool = false,
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
                .{
                    .long_name = "log-file",
                    .help = "path to debug log file (enables debug logging)",
                    .value_ref = r.mkRef(&config.log_file),
                },
                .{
                    .long_name = "indent-style",
                    .help = "indentation style: 'tabs', 'spaces', or 'auto-detect'",
                    .value_ref = r.mkRef(&config.indent_style),
                },
                .{
                    .long_name = "indent-width",
                    .help = "indentation width (number of spaces, default: 4)",
                    .value_ref = r.mkRef(&config.indent_width),
                },
                .{
                    .long_name = "auto-detect-indent",
                    .help = "auto-detect indentation style from input files",
                    .value_ref = r.mkRef(&config.auto_detect_indent),
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

fn createIndentConfig(file_content: ?[]const u8) !IndentConfig {
    // If auto-detect is enabled, try to detect from file content
    if (config.auto_detect_indent) {
        if (file_content) |content| {
            return IndentConfig.detectFromSource(content);
        }
    }

    // Use explicit configuration if provided
    if (config.indent_style) |style_str| {
        if (std.mem.eql(u8, style_str, "tabs")) {
            return IndentConfig{
                .style = .tabs,
                .width = config.indent_width,
                .auto_detect = false,
            };
        } else if (std.mem.eql(u8, style_str, "spaces")) {
            return IndentConfig{
                .style = .spaces,
                .width = config.indent_width,
                .auto_detect = false,
            };
        } else if (std.mem.eql(u8, style_str, "auto-detect")) {
            if (file_content) |content| {
                return IndentConfig.detectFromSource(content);
            }
        } else {
            try logging.printErrorAndExit("Error: invalid indent-style '{s}'. Must be 'tabs', 'spaces', or 'auto-detect'\n", .{style_str});
        }
    }

    // Default configuration
    return IndentConfig{
        .style = .spaces,
        .width = config.indent_width,
        .auto_detect = false,
    };
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

    for (config.files) |path| {
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            try logging.printErrorAndExit("Error: failed to open file '{s}': {}\n", .{ path, err });
        };
        defer file.close();

        // Read file content for indentation detection
        const file_content = try file.readToEndAlloc(arena_allocator, std.math.maxInt(usize));

        // Create indentation configuration
        const indent_config = try createIndentConfig(file_content);
        const indent_string = try indent_config.generateIndentString(arena_allocator);

        // Reset file position for parsing
        try file.seekTo(0);

        var tree = ts_parser.parseFile(arena_allocator, file) catch |err| {
            try logging.printErrorAndExit("Error: failed to parse file '{s}': {}\n", .{ path, err });
        };
        defer tree.deinit();

        const root_node = tree.rootNode();
        var cursor = root_node.cursor();

        var gd_writer = @import("GdWriter.zig").init(.{
            .writer = writer,
            .context = .{
                .indent_str = indent_string,
                .indent_type = indent_config.style,
                .indent_size = indent_config.width,
            },
            .allocator = arena_allocator,
        });

        formatter.depthFirstWalk(&cursor, &gd_writer) catch |err| {
            try logging.printErrorAndExit("Error: failed to format file '{s}': {}\n", .{ path, err });
        };
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

    var it = dir.iterateAssumeFirstIteration();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;

        if (std.mem.endsWith(u8, entry.name, ".in.gd")) {
            std.debug.print("Processing input file: {s}\n", .{entry.name});

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

            // Use default indentation for tests (spaces, width 4)
            const default_indent_config = IndentConfig{
                .style = .spaces,
                .width = 4,
                .auto_detect = false,
            };
            const indent_string = try default_indent_config.generateIndentString(allocator);

            var gd_writer = @import("GdWriter.zig").init(.{
                .writer = writer,
                .context = .{
                    .indent_str = indent_string,
                    .indent_type = default_indent_config.style,
                    .indent_size = default_indent_config.width,
                },
                .allocator = allocator,
            });

            try formatter.depthFirstWalk(&cursor, &gd_writer);
            try writer.flush();
        }
    }
}

const ArenaAllocator = std.heap.ArenaAllocator;
const testing = std.testing;

extern fn tree_sitter_gdscript() ?*anyopaque;
