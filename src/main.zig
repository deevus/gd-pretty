const std = @import("std");
const ts = @import("tree-sitter");
const gd = @import("tree-sitter-gdscript");
const c_allocator = std.heap.raw_c_allocator;

const TSParser = ts.TSParser;

const GdNodeType = enum {
    source,
};

pub fn main() !void {
    const ts_parser = TSParser.init();
    defer ts_parser.deinit();

    const ts_gdscript = gd.tree_sitter_gdscript();
    const success = ts_parser.setLanguage(@ptrCast(ts_gdscript));

    std.log.info("gdscript loaded: {}", .{success});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var cli_args = try std.process.argsWithAllocator(allocator);
    defer cli_args.deinit();

    // skip the first arg, which is the program name
    _ = cli_args.next();

    var paths = std.ArrayList([]const u8).init(allocator);
    defer paths.deinit();

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

        const tree = try ts_parser.parseString(buf);
        defer tree.deinit();

        const root_node = tree.rootNode();
        std.log.debug("node type: {s}", .{root_node.getTypeAsString()});

        const child_count = root_node.namedChildCount();
        if (child_count > 0) {
            for (0..child_count) |i| {
                const node = root_node.namedChild(@intCast(i)).?;
                const value = buf[node.startByte()..node.endByte()];
                const node_type = try node.getTypeAsEnum(GdNodeType);

                std.log.debug("node type: {s}", .{node_type});
                std.log.debug("node value: {s}", .{value});
            }
        }
    }
}
