const std = @import("std");
const TSNode = @import("tree-sitter").TSNode;
const Context = @import("Context.zig");
const enums = @import("enums.zig");

const NodeType = enums.GdNodeType;

pub const Error = error{MissingRequiredChild} || std.Io.Writer.Error;

// Trims leading and trailing whitespace from text
// Note: This function is duplicated in GdWriter.zig for use there.
// Kept separate to avoid circular dependencies between modules.
fn trimWhitespace(text: []const u8) []const u8 {
    return std.mem.trim(u8, text, &std.ascii.whitespace);
}

pub fn writeType(node: TSNode, writer: anytype, context: Context) Error!void {
    for (0..node.childCount()) |i| {
        const child = node.child(@intCast(i)) orelse return Error.MissingRequiredChild;
        const child_type = (child.getTypeAsEnum(NodeType)).?;

        switch (child_type) {
            .subscript => try writeSubscript(child, writer, context),
            else => try writer.writeAll(trimWhitespace(child.text())),
        }
    }
}

pub fn writeSubscript(node: TSNode, writer: anytype, context: Context) Error!void {
    _ = context;

    for (0..node.childCount()) |i| {
        const child = node.child(@intCast(i)) orelse return Error.MissingRequiredChild;
        try writer.writeAll(trimWhitespace(child.text()));
    }
}
