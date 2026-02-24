const logger = std.log.scoped(.debug);

pub const Error = error{
    AssertNodeTypeEquals,
};

pub fn debugAssert(condition: bool) void {
    if (comptime builtin.mode == .Debug) {
        std.debug.assert(condition);
    }
}

pub fn assertNodeIsType(expected: NodeType, node: ?Node) !void {
    if (comptime builtin.mode == .Debug) {
        const actual = blk: {
            if (node) |n| {
                break :blk n.getTypeAsEnum(NodeType);
            }
            break :blk null;
        };

        if (expected != actual) {
            logger.err("Expected node type {s}, but got {?s}", .{ @tagName(expected), if (actual) |nt| @tagName(nt) else null });
            return error.AssertNodeTypeEquals;
        }
    }
}

const std = @import("std");
const builtin = @import("builtin");

const enums = @import("enums.zig");
const NodeType = enums.GdNodeType;

const ts = @import("tree-sitter");
const Node = ts.TSNode;
