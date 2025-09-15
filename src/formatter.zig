const logger = std.log.scoped(.formatter);

const WriteFn = *const fn (writer: *GdWriter, node: ts.TSNode) GdWriter.Error!void;

const NodeTypeMapValue = struct {
    exists: bool,
    write_fn: ?WriteFn = null,
};

const node_type_map = std.static_string_map.StaticStringMap(NodeTypeMapValue).initComptime(blk: {
    @setEvalBranchQuota(150_000);

    const enum_fields = std.meta.fieldNames(GdNodeType);
    var result: [enum_fields.len]struct { []const u8, NodeTypeMapValue } = undefined;

    for (enum_fields, 0..) |field_name, i| {
        var buf: ["write_".len + field_name.len]u8 = undefined;
        @memcpy(&buf, "write_" ++ field_name);
        const write_fn = case.comptimeTo(.camel, &buf) catch unreachable;

        if (@hasDecl(GdWriter, write_fn)) {
            result[i] = .{
                field_name, .{
                    .exists = true,
                    .write_fn = @field(GdWriter, write_fn),
                },
            };
        } else {
            result[i] = .{
                field_name, .{
                    .exists = false,
                },
            };
        }
    }

    break :blk result;
});

pub fn writeIndent(writer: anytype, context: Context) !void {
    if (context.indent_level == 0) {
        return;
    }

    for (0..context.indent_level) |_| {
        try writer.writeAll(context.indent_str);
    }
}

pub fn depthFirstWalk(cursor: *ts.TSTreeCursor, gd_writer: *GdWriter) GdWriter.Error!void {
    const current_node = cursor.currentNode();
    const node_type = current_node.getTypeAsEnum(GdNodeType);

    logger.debug("Node type: {s}", .{current_node.getTypeAsString()});

    if (node_type) |nt| {
        var handled = false;
        const tag_name = @tagName(nt);

        if (node_type_map.get(tag_name)) |handler| if (handler.exists) {
            try handler.write_fn.?(gd_writer, current_node);
            handled = true;
        };

        if (!handled and cursor.gotoFirstChild()) {
            try depthFirstWalk(cursor, gd_writer);
            _ = cursor.gotoParent();
        }

        while (cursor.gotoNextSibling()) {
            try depthFirstWalk(cursor, gd_writer);
        }
    }
}

pub fn trimWhitespace(text: []const u8) []const u8 {
    return std.mem.trim(u8, text, &std.ascii.whitespace);
}

pub fn printTree(root: ts.TSNode, writer: anytype) !void {
    try printTreeRecursive(root, writer, 0);
}

fn printTreeRecursive(root: ts.TSNode, writer: anytype, depth: usize) !void {
    for (0..depth) |_| {
        try writer.writeAll("  ");
    }
    try writer.writeAll(root.getTypeAsString());
    try writer.writeAll("\n");

    for (0..root.childCount()) |i| {
        const child = root.child(@intCast(i)) orelse return; // Skip invalid children
        try printTreeRecursive(child, writer, depth + 1);
    }
}

const std = @import("std");
const Writer = std.Io.Writer;

const ts = @import("tree-sitter");
const case = @import("case");

const enums = @import("enums.zig");
const GdNodeType = enums.GdNodeType;

const Context = @import("Context.zig");
const attribute = @import("attribute.zig");
const GdWriter = @import("GdWriter.zig");
