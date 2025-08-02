const IndentType = @import("enums.zig").IndentType;

const Context = @This();

indent_level: u32 = 0,
indent_str: []const u8 = "    ",
indent_size: u32 = 4,
indent_type: IndentType = .spaces,
max_width: u32 = 100,

pub fn indent(self: Context) Context {
    return .{
        .indent_level = self.indent_level + 1,
        .indent_str = self.indent_str,
        .indent_size = self.indent_size,
        .indent_type = self.indent_type,
        .max_width = self.max_width,
    };
}

pub fn deindent(self: Context) Context {
    return .{
        .indent_level = @max(0, self.indent_level - 1),
        .indent_str = self.indent_str,
        .indent_size = self.indent_size,
        .indent_type = self.indent_type,
        .max_width = self.max_width,
    };
}
