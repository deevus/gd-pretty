const ffi = @import("ffi.zig");

const TSTree = @This();
const TSNode = @import("TSNode.zig");

ptr: *ffi.TSTree,
input: []const u8,

pub inline fn init(ptr: *ffi.TSTree, input: []const u8) TSTree {
    return .{
        .ptr = ptr,
        .input = input,
    };
}

pub inline fn deinit(self: TSTree) void {
    ffi.ts_tree_delete(self.ptr);
}

pub inline fn rootNode(self: *TSTree) TSNode {
    return .{
        .handle = ffi.ts_tree_root_node(self.ptr),
        .tree = self,
    };
}
