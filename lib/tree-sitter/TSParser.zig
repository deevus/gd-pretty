const std = @import("std");
const ffi = @import("ffi.zig");

const TSParser = @This();
const TSTree = @import("TSTree.zig");

ptr: *ffi.TSParser,

pub inline fn init() TSParser {
    return .{
        .ptr = ffi.ts_parser_new().?,
    };
}

pub inline fn deinit(self: TSParser) void {
    ffi.ts_parser_delete(self.ptr);
}

pub inline fn getLanguage(self: TSParser) ?*const ffi.TSLanguage {
    return ffi.ts_parser_language(self.ptr);
}

pub inline fn setLanguage(self: TSParser, language: *const ffi.TSLanguage) bool {
    return ffi.ts_parser_set_language(self.ptr, language);
}

pub inline fn parseString(self: TSParser, input: []const u8) !TSTree {
    const tree = ffi.ts_parser_parse_string(self.ptr, null, input.ptr, @intCast(input.len));

    if (tree) |t| {
        return .{
            .ptr = t,
        };
    } else {
        return error.ParseFailed;
    }
}
