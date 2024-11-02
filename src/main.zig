const std = @import("std");
const ts = @import("tree-sitter");
const gd = @import("tree-sitter-gdscript");
const c_allocator = std.heap.raw_c_allocator;

pub fn main() !void {
    const ts_parser = ts.ts_parser_new().?;
    defer ts.ts_parser_delete(ts_parser);

    const ts_gdscript: ?*ts.struct_TSLanguage = @ptrCast(gd.tree_sitter_gdscript());
    const success = ts.ts_parser_set_language(ts_parser, ts_gdscript);

    std.log.info("gdscript loaded: {}", .{success});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var cli_args = try std.process.argsWithAllocator(allocator);
    defer cli_args.deinit();

    // skip the first arg, which is the program name
    _ = cli_args.next();

    var paths = std.ArrayList([]const u8).init(allocator);
    while (cli_args.next()) |arg| {
        try paths.append(arg);
    }

    // no paths provided
    if (paths.items.len == 0) {
        std.log.err("no paths provided", .{});
        return;
    }

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var arena_allocator = arena.allocator();

    for (paths.items) |path| {
        const file = try std.fs.cwd().openFile(path, .{});

        const buf = try arena_allocator.alloc(u8, try file.getEndPos());
        _ = try file.readAll(buf);

        const tree = ts.ts_parser_parse_string(ts_parser, null, buf.ptr, @intCast(buf.len)).?;
        defer ts.ts_tree_delete(tree);

        const root_node = ts.ts_tree_root_node(tree);
        const cursor = ts.ts_tree_cursor_new(root_node);
        _ = cursor;
    }
}
