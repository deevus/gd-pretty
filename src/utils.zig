const Context = @import("Context.zig");

pub fn writeIndent(writer: anytype, context: Context) !void {
    if (context.indent_level == 0) {
        return;
    }

    for (0..context.indent_level) |_| {
        try writer.writeAll(context.indent_str);
    }
}
