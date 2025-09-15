const std = @import("std");
const TSNode = @import("tree-sitter").TSNode;
const Context = @import("Context.zig");
const formatter = @import("formatter.zig");
const enums = @import("enums.zig");

const NodeType = enums.GdNodeType;
const assert = std.debug.assert;

pub fn writeAttribute(node: TSNode, writer: anytype, context: Context) anyerror!void {
    assert((node.getTypeAsEnum(NodeType)).? == .attribute);

    var cursor = node.child(0).?.cursor();
    try formatter.depthFirstWalk(&cursor, writer, context);
}
