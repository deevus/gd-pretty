const std = @import("std");
const ts = @import("tree-sitter");
const gd = @import("tree-sitter-gdscript");
const c_allocator = std.heap.raw_c_allocator;

const TSParser = ts.TSParser;
const Context = @import("Context.zig");
const enums = @import("enums.zig");
const formatter = @import("formatter.zig");
const statements = @import("statements.zig");

const GdNodeType = enums.GdNodeType;

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

    var stdout = std.io.getStdOut();
    const stdout_writer = stdout.writer();

    var buffered_writer = std.io.bufferedWriter(stdout_writer);
    const br = buffered_writer.writer();
    defer buffered_writer.flush() catch {};

    var counting_writer = std.io.countingWriter(br);
    const writer = counting_writer.writer().any();

    for (paths.items) |path| {
        const file = try std.fs.cwd().openFile(path, .{});

        const buf = try arena_allocator.alloc(u8, try file.getEndPos());
        _ = try file.readAll(buf);

        var tree = try ts_parser.parseString(buf);
        defer tree.deinit();

        const root_node = tree.rootNode();

        var cursor = root_node.cursor();

        try formatter.depthFirstWalk(&cursor, writer, .{});

        try formatter.printTree(root_node, std.io.getStdOut().writer());
    }
}
