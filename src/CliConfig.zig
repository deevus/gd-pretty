files: []const []const u8 = &.{},
version: bool = false,
log_file: ?[]const u8 = null,
indent_type: ?enums.IndentType = null,
indent_width: u32 = 4,
allocator: std.mem.Allocator = undefined,

const std = @import("std");
const enums = @import("enums.zig");
