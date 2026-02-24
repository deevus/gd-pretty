const std = @import("std");
const ffi = @import("tree-sitter-c");

const TSNode = @This();
const TSTree = @import("TSTree.zig");
const TSTreeCursor = @import("TSTreeCursor.zig");

handle: ffi.TSNode,
tree: *TSTree,

pub inline fn init(handle: ffi.TSNode, tree: *TSTree) TSNode {
    return .{
        .handle = handle,
        .tree = tree,
    };
}

pub inline fn cursor(self: TSNode) TSTreeCursor {
    return TSTreeCursor.init(self);
}

pub inline fn childCount(self: TSNode) usize {
    return @intCast(ffi.ts_node_child_count(self.handle));
}

pub inline fn startByte(self: TSNode) u32 {
    return ffi.ts_node_start_byte(self.handle);
}

pub inline fn endByte(self: TSNode) u32 {
    return ffi.ts_node_end_byte(self.handle);
}

pub inline fn text(self: TSNode) []const u8 {
    return self.tree.input[self.startByte()..self.endByte()];
}

pub inline fn startPoint(self: TSNode) ffi.TSPoint {
    return ffi.ts_node_start_point(self.handle);
}

pub inline fn endPoint(self: TSNode) ffi.TSPoint {
    return ffi.ts_node_end_point(self.handle);
}

fn nodeOrNull(self: TSNode, node: ffi.TSNode) ?TSNode {
    if (ffi.ts_node_is_null(node)) {
        return null;
    }

    return TSNode.init(node, self.tree);
}

pub inline fn nextSibling(self: TSNode) ?TSNode {
    const node = ffi.ts_node_next_sibling(self.handle);

    return self.nodeOrNull(node);
}

pub inline fn prevSibling(self: TSNode) ?TSNode {
    const node = ffi.ts_node_prev_sibling(self.handle);

    return self.nodeOrNull(node);
}

pub inline fn parent(self: TSNode) ?TSNode {
    return self.nodeOrNull(ffi.ts_node_parent(self.handle));
}

pub inline fn child(self: TSNode, index: usize) ?TSNode {
    return self.nodeOrNull(ffi.ts_node_child(self.handle, @intCast(index)));
}

pub inline fn isNamed(self: TSNode) bool {
    return ffi.ts_node_is_named(self.handle);
}

pub inline fn namedChildCount(self: TSNode) usize {
    return @intCast(ffi.ts_node_named_child_count(self.handle));
}

pub inline fn namedChild(self: TSNode, index: usize) ?TSNode {
    return self.nodeOrNull(ffi.ts_node_named_child(self.handle, @intCast(index)));
}

pub inline fn nextNamedSibling(self: TSNode) ?TSNode {
    return self.nodeOrNull(ffi.ts_node_next_named_sibling(self.handle));
}

pub inline fn prevNamedSibling(self: TSNode) ?TSNode {
    return self.nodeOrNull(ffi.ts_node_prev_named_sibling(self.handle));
}

pub inline fn getTypeAsString(self: TSNode) []const u8 {
    return std.mem.span(ffi.ts_node_type(self.handle));
}

pub fn getTypeAsEnum(self: TSNode, comptime E: type) ?E {
    const node_type = self.getTypeAsString();
    var buf: [128]u8 = undefined;

    const slice = std.fmt.bufPrint(&buf, "{s}", .{node_type}) catch return null;

    return std.meta.stringToEnum(E, slice);
}

pub inline fn eql(self: TSNode, other: TSNode) bool {
    return ffi.ts_node_eq(self.handle, other.handle);
}

pub inline fn toString(self: TSNode) []const u8 {
    return std.mem.span(ffi.ts_node_string(self.handle));
}

pub fn format(self: TSNode, writer: *Writer) Writer.Error!void {
    try writer.writeAll(self.toString());
}

pub inline fn symbol(self: TSNode) ffi.TSSymbol {
    return ffi.ts_node_symbol(self.handle);
}

pub fn firstChildOfType(self: TSNode, comptime enum_value: anytype) !?TSNode {
    const child_count = self.childCount();
    for (0..child_count) |i| {
        const c = self.child(i) orelse continue;
        const child_type = c.getTypeAsEnum(@TypeOf(enum_value)) orelse continue;

        if (child_type == enum_value) {
            return c;
        }
    }

    return null;
}

const Writer = std.Io.Writer;
