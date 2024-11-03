const std = @import("std");
const ffi = @import("ffi.zig");

const TSNode = @This();
const TSTreeCursor = @import("TSTreeCursor.zig");

handle: ffi.TSNode,

pub inline fn init(handle: ffi.TSNode) TSNode {
    return .{
        .handle = handle,
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

pub inline fn startPoint(self: TSNode) ffi.TSPoint {
    return ffi.ts_node_start_point(self.handle);
}

pub inline fn endPoint(self: TSNode) ffi.TSPoint {
    return ffi.ts_node_end_point(self.handle);
}

fn nodeOrNull(node: ffi.TSNode) ?TSNode {
    if (ffi.ts_node_is_null(node)) {
        return null;
    }

    return TSNode.init(node);
}

pub inline fn nextSibling(self: TSNode) ?TSNode {
    const node = ffi.ts_node_next_sibling(self.handle);

    return nodeOrNull(node);
}

pub inline fn prevSibling(self: TSNode) ?TSNode {
    const node = ffi.ts_node_prev_sibling(self.handle);

    return nodeOrNull(node);
}

pub inline fn parent(self: TSNode) ?TSNode {
    return nodeOrNull(ffi.ts_node_parent(self.handle));
}

pub inline fn child(self: TSNode, index: u32) ?TSNode {
    return nodeOrNull(ffi.ts_node_child(self.handle, index));
}

pub inline fn isNamed(self: TSNode) bool {
    return ffi.ts_node_is_named(self.handle);
}

pub inline fn namedChildCount(self: TSNode) usize {
    return @intCast(ffi.ts_node_named_child_count(self.handle));
}

pub inline fn namedChild(self: TSNode, index: u32) ?TSNode {
    return nodeOrNull(ffi.ts_node_named_child(self.handle, index));
}

pub inline fn nextNamedSibling(self: TSNode) ?TSNode {
    return nodeOrNull(ffi.ts_node_next_named_sibling(self.handle));
}

pub inline fn prevNamedSibling(self: TSNode) ?TSNode {
    return nodeOrNull(ffi.ts_node_prev_named_sibling(self.handle));
}

pub inline fn getTypeAsString(self: TSNode) [*c]const u8 {
    return ffi.ts_node_type(self.handle);
}

pub fn getTypeAsEnum(self: TSNode, comptime E: type) !?E {
    const node_type = self.getTypeAsString();
    var buf: [128]u8 = undefined;

    const slice = try std.fmt.bufPrint(&buf, "{s}", .{node_type});

    return std.meta.stringToEnum(E, slice);
}

pub inline fn equals(self: TSNode, other: TSNode) bool {
    return ffi.ts_node_eq(self.handle, other.handle);
}

pub inline fn toString(self: TSNode) [*c]u8 {
    return ffi.ts_node_string(self.handle);
}

pub inline fn symbol(self: TSNode) ffi.TSSymbol {
    return ffi.ts_node_symbol(self.handle);
}
