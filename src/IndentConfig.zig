const logger = std.log.scoped(.indent_config);

const IndentConfig = @This();

/// The style of indentation to use
style: IndentType = .spaces,
/// The width of indentation (number of spaces or tab width)
width: u32 = 4,

pub fn spaces(width: u32) IndentConfig {
    return .{
        .style = .spaces,
        .width = width,
    };
}

pub const tabs: IndentConfig = .{
    .style = .tabs,
};

pub const default = spaces(4);

/// Auto-detect indentation style from source code
pub fn fromSourceFile(source_file: File) !IndentConfig {
    logger.debug("Auto-detecting indentation style from source file", .{});

    var buf: [1024]u8 = undefined;
    var file_reader = source_file.reader(&buf);
    var reader = &file_reader.interface;
    var line_num: usize = 0;

    // Consume lines until we find a line with leading whitespace
    while (true) {
        const line = reader.takeDelimiterExclusive('\n') catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };

        if (line.len > 0 and (line[0] == ' ' or line[0] == '\t')) {
            // Count leading whitespace
            var i: usize = 0;

            if (line.len > 0 and line[0] == '\t') {
                logger.debug("Detected tabs indentation style on line {d}", .{line_num});
                return .tabs;
            }

            var spaces_count: u32 = 0;
            while (i < line.len and line[i] == ' ') {
                spaces_count += 1;
                i += 1;
            }

            if (spaces_count > 0) {
                logger.debug("Detected spaces indentation style on line {d}. Width: {d}", .{ line_num, spaces_count });
                return .spaces(spaces_count);
            }
        }

        line_num += 1;
    }

    logger.debug("Could not detect indentation style from source file. Using default: {}", .{default.style});
    return .default;
}

pub fn fromCliConfig(cli_config: CliConfig) ?IndentConfig {
    const indent_config: ?IndentConfig = if (cli_config.indent_type) |indent_type| switch (indent_type) {
        .tabs => IndentConfig.tabs,
        .spaces => IndentConfig.spaces(cli_config.indent_width),
    } else null;

    if (indent_config) |config| {
        logger.debug("Using indentation style from CLI. Style: {}", .{config.style});

        if (config.style == .spaces) {
            logger.debug("Width: {d}", .{config.width});
        }

        return config;
    }

    return null;
}

const std = @import("std");
const File = std.fs.File;

const enums = @import("enums.zig");
const IndentType = enums.IndentType;

const CliConfig = @import("CliConfig.zig");
