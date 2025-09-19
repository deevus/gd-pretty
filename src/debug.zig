pub fn debugAssert(condition: bool) void {
    if (comptime builtin.mode == .Debug) {
        std.debug.assert(condition);
    }
}

const std = @import("std");
const builtin = @import("builtin");
