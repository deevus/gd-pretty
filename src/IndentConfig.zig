const std = @import("std");
const IndentType = @import("enums.zig").IndentType;

const IndentConfig = @This();

/// The style of indentation to use
style: IndentType = .spaces,
/// The width of indentation (number of spaces or tab width)
width: u32 = 4,
/// Whether to auto-detect indentation from input
auto_detect: bool = false,

/// Generate the indentation string based on configuration
pub fn generateIndentString(self: IndentConfig, allocator: std.mem.Allocator) ![]const u8 {
    switch (self.style) {
        .tabs => {
            return try allocator.dupe(u8, "\t");
        },
        .spaces => {
            const spaces = try allocator.alloc(u8, self.width);
            @memset(spaces, ' ');
            return spaces;
        },
    }
}

/// Auto-detect indentation style from source code
pub fn detectFromSource(source: []const u8) IndentConfig {
    var line_start: usize = 0;
    var spaces_count: u32 = 0;
    var tabs_count: u32 = 0;
    var first_indent_width: ?u32 = null;

    // Look at each line to detect indentation
    while (line_start < source.len) {
        const line_end = std.mem.indexOfScalarPos(u8, source, line_start, '\n') orelse source.len;
        const line = source[line_start..line_end];

        if (line.len > 0 and (line[0] == ' ' or line[0] == '\t')) {
            // Count leading whitespace
            var i: usize = 0;
            var current_spaces: u32 = 0;
            var has_tabs = false;

            while (i < line.len and (line[i] == ' ' or line[i] == '\t')) {
                if (line[i] == '\t') {
                    has_tabs = true;
                    tabs_count += 1;
                } else {
                    current_spaces += 1;
                }
                i += 1;
            }

            if (has_tabs) {
                // If we find any tabs, assume tabs are preferred
                return IndentConfig{
                    .style = .tabs,
                    .width = 4, // Default tab width
                    .auto_detect = true,
                };
            } else if (current_spaces > 0) {
                spaces_count += 1;
                if (first_indent_width == null) {
                    first_indent_width = current_spaces;
                }
            }
        }

        line_start = line_end + 1;
    }

    // Determine the style based on what we found
    if (tabs_count > 0) {
        return IndentConfig{
            .style = .tabs,
            .width = 4,
            .auto_detect = true,
        };
    } else if (spaces_count > 0) {
        return IndentConfig{
            .style = .spaces,
            .width = first_indent_width orelse 4,
            .auto_detect = true,
        };
    }

    // Default if no indentation detected
    return IndentConfig{
        .style = .spaces,
        .width = 4,
        .auto_detect = true,
    };
}
