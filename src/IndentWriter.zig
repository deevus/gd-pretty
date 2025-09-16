const IndentWriter = @This();

config: WhitespaceConfig,

pub fn init(config: WhitespaceConfig) IndentWriter {
    return .{ .config = config };
}

pub fn writeIndent(self: IndentWriter, writer: *Writer, context: Context) !void {
    switch (self.config.style) {
        .spaces => try self.writeSpaces(writer, context),
        .tabs => try self.writeTabs(writer, context),
    }
}

fn writeSpaces(self: IndentWriter, writer: *Writer, context: Context) !void {
    const width = self.config.width * context.indent_level;
    for (0..width) |_| try writer.writeByte(' ');
}

fn writeTabs(self: IndentWriter, writer: *Writer, context: Context) !void {
    _ = self;
    for (0..context.indent_level) |_| try writer.writeByte('\t');
}

const std = @import("std");
const Writer = std.Io.Writer;

const WhitespaceConfig = @import("WhitespaceConfig.zig");
const Context = @import("Context.zig");
