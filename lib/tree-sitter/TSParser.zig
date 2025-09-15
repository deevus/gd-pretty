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
        return TSTree.init(t, input);
    } else {
        return error.ParseFailed;
    }
}

pub fn parseFile(self: TSParser, allocator: Allocator, file: File) !TSTree {
    var buf: [1024]u8 = undefined;
    var file_reader = file.reader(&buf);
    var reader = &file_reader.interface;

    const file_contents = try reader.allocRemaining(allocator, .unlimited);
    return try self.parseString(file_contents);
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const File = std.fs.File;

const ffi = @import("tree-sitter-c");

const TSParser = @This();
const TSTree = @import("TSTree.zig");
