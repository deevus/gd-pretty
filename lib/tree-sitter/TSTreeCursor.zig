const std = @import("std");
const ffi = @import("ffi.zig");

const TSTreeCursor = @This();
const TSTree = @import("TSTree.zig");
const TSNode = @import("TSNode.zig");

handle: ffi.TSTreeCursor,
tree: *TSTree,

pub inline fn init(node: TSNode) TSTreeCursor {
    return .{
        .handle = ffi.ts_tree_cursor_new(node.handle),
        .tree = node.tree,
    };
}

pub inline fn gotoFirstChild(self: *TSTreeCursor) bool {
    return ffi.ts_tree_cursor_goto_first_child(&self.handle);
}

pub inline fn gotoNextSibling(self: *TSTreeCursor) bool {
    return ffi.ts_tree_cursor_goto_next_sibling(&self.handle);
}

pub inline fn gotoParent(self: *TSTreeCursor) bool {
    return ffi.ts_tree_cursor_goto_parent(&self.handle);
}

pub inline fn currentNode(self: TSTreeCursor) TSNode {
    const node = ffi.ts_tree_cursor_current_node(&self.handle);

    return TSNode.init(node, self.tree);
}

pub inline fn currentFieldName(self: *TSTreeCursor) ?[]const u8 {
    const field_name = ffi.ts_tree_cursor_current_field_name(&self.handle);

    if (field_name == 0) {
        return null;
    }

    return std.mem.span(field_name);
}
