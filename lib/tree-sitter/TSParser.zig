const std = @import("std");
const ffi = @import("ffi.zig");

const TSParser = @This();

ptr: *ffi.struct_TSParser,

pub fn init() TSParser {
    return .{
        .ptr = ffi.ts_parser_new().?,
    };
}

pub fn getLanguage(self: TSParser) *const ffi.struct_TSLanguage {
    return ffi.ts_parser_language(self.ptr).?;
}

pub fn deinit(self: TSParser) void {
    ffi.ts_parser_delete(self.ptr);
}
