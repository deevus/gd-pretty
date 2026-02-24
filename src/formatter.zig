const logger = std.log.scoped(.formatter);

const WriteFn = *const fn (writer: *GdWriter, node: ts.TSNode) GdWriter.Error!void;

const NodeTypeMapValue = struct {
    exists: bool,
    write_fn: ?WriteFn = null,
};

const symbol_node_type_names = std.StaticStringMap([]const u8).initComptime(.{
    .{ ":=", "infer_assign" },
    .{ "@", "at" },
    .{ "(", "left_paren" },
    .{ ")", "right_paren" },
    .{ "[", "left_bracket" },
    .{ "]", "right_bracket" },
    .{ "{", "left_brace" },
    .{ "}", "right_brace" },
    .{ ",", "comma" },
    .{ ".", "dot" },
    .{ ":", "colon" },
    .{ ";", "semicolon" },
    .{ "+", "plus" },
    .{ "+=", "plus_assign" },
    .{ "-", "minus" },
    .{ "*", "star" },
    .{ "/", "slash" },
    .{ "%", "percent" },
    .{ "<", "less" },
    .{ ">", "greater" },
    .{ "<=", "less_equal" },
    .{ ">=", "greater_equal" },
    .{ "==", "equal" },
    .{ "!=", "not_equal" },
    .{ "=", "assign" },
    .{ "&&", "and" },
    .{ "||", "or" },
    .{ "!", "not" },
    .{ "\"", "quote" },
    .{ "->", "arrow" },
});

fn nodeTypeTagNameFriendly(nt: anytype) []const u8 {
    const nt_str = switch (@TypeOf(nt)) {
        []u8, []const u8, [:0]u8, [:0]const u8 => nt,
        else => @tagName(nt),
    };

    return symbol_node_type_names.get(nt_str) orelse nt_str;
}

const node_type_map = std.static_string_map.StaticStringMap(NodeTypeMapValue).initComptime(blk: {
    @setEvalBranchQuota(150_000);

    const enum_fields = std.meta.fieldNames(GdNodeType);
    var result: [enum_fields.len]struct { []const u8, NodeTypeMapValue } = undefined;

    for (enum_fields, 0..) |raw_field_name, i| {
        const field_name = nodeTypeTagNameFriendly(raw_field_name);
        var buf: ["write_".len + field_name.len]u8 = undefined;
        @memcpy(&buf, "write_" ++ field_name);
        const write_fn = case.comptimeTo(.camel, &buf) catch std.debug.panic("Failed to convert field name to camel case", {});

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

pub fn renderNode(node: ts.TSNode, writer: *GdWriter) GdWriter.Error!void {
    var cursor = node.cursor();
    try depthFirstWalk(&cursor, writer);
}

pub fn depthFirstWalk(cursor: *ts.TSTreeCursor, gd_writer: *GdWriter) GdWriter.Error!void {
    const current_node = cursor.currentNode();
    const node_type = current_node.getTypeAsEnum(GdNodeType);

    logger.debug("Node type: {s}", .{current_node.getTypeAsString()});

    if (node_type) |nt| {
        var handled = false;
        const tag_name = nodeTypeTagNameFriendly(nt);

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
        const child = root.child(i) orelse return; // Skip invalid children
        try printTreeRecursive(child, writer, depth + 1);
    }
}

const std = @import("std");

const ts = @import("tree-sitter");
const case = @import("case");

const enums = @import("enums.zig");
const GdNodeType = enums.GdNodeType;

const GdWriter = @import("GdWriter.zig");
