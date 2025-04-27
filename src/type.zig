const std = @import("std");
const TSNode = @import("tree-sitter").TSNode;
const Context = @import("Context.zig");
const formatter = @import("formatter.zig");
const enums = @import("enums.zig");

const NodeType = enums.GdNodeType;
const assert = std.debug.assert;

pub fn writeType(node: TSNode, writer: anytype, context: Context) !void {
    for (0..node.childCount()) |i| {
        const child = node.child(@intCast(i)) orelse unreachable;
        const child_type = (try child.getTypeAsEnum(NodeType)).?;

        switch (child_type) {
            .subscript => try writeSubscript(child, writer, context),
            else => try writer.writeAll(formatter.trimWhitespace(child.text())),
        }
    }
}

pub fn writeSubscript(node: TSNode, writer: anytype, context: Context) !void {
    _ = context;

    for (0..node.childCount()) |i| {
        const child = node.child(@intCast(i)) orelse unreachable;
        try writer.writeAll(formatter.trimWhitespace(child.text()));
    }
}
