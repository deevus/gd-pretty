const std = @import("std");
const ts = @import("tree-sitter");
const gd = @import("tree-sitter-gdscript");
const c_allocator = std.heap.raw_c_allocator;

const TSParser = ts.TSParser;
const Context = @import("Context.zig");
const enums = @import("enums.zig");
const utils = @import("utils.zig");

const statements = @import("statements.zig");

const GdNodeType = enums.GdNodeType;

var unknown_node_types: std.ArrayList([*c]const u8) = undefined;

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

    unknown_node_types = std.ArrayList([*c]const u8).init(arena_allocator);

    var stdout = std.io.getStdOut();
    const stdout_writer = stdout.writer();

    var buffered_writer = std.io.bufferedWriter(stdout_writer);
    const br = buffered_writer.writer();

    for (paths.items) |path| {
        const file = try std.fs.cwd().openFile(path, .{});

        const buf = try arena_allocator.alloc(u8, try file.getEndPos());
        _ = try file.readAll(buf);

        var tree = try ts_parser.parseString(buf);
        defer tree.deinit();

        const root_node = tree.rootNode();

        var cursor = root_node.cursor();

        try depthFirstWalk(&cursor, br, .{});
    }

    if (unknown_node_types.items.len > 0) {
        std.log.warn("unknown node types", .{});

        for (unknown_node_types.items) |node_type| {
            std.log.warn("{s}", .{node_type});
        }
    }

    try buffered_writer.flush();
}

fn noOp(node: ts.TSNode, writer: anytype, context: Context) anyerror!void {
    _ = node;
    _ = writer;
    _ = context;

    return;
}

fn depthFirstWalk(cursor: *ts.TSTreeCursor, writer: anytype, context: Context) !void {
    try utils.writeIndent(writer, context);

    const current_node = cursor.currentNode();
    const node_type = try current_node.getTypeAsEnum(GdNodeType);

    if (node_type) |nt| {
        // for (0..context.indent_level) |_| {
        //     std.debug.print("{s}", .{context.indent_str});
        // }

        // std.debug.print("{}\n", .{nt});

        switch (nt) {
            .extends_statement => try statements.extends_statement(current_node, writer, context),
            .variable_statement => try statements.variable_statement(current_node, writer, context),
            else => {},
        }
    } else {
        try unknown_node_types.append(current_node.getTypeAsString());
    }

    if (cursor.gotoFirstChild()) {
        try depthFirstWalk(cursor, writer, context);
        _ = cursor.gotoParent();
    }

    while (cursor.gotoNextSibling()) {
        try depthFirstWalk(cursor, writer, context);
    }
}
