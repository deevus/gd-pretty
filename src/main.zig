const std = @import("std");
const ts = @import("tree-sitter");
const gd = @import("tree-sitter-gdscript");
const c_allocator = std.heap.raw_c_allocator;

const TSParser = ts.TSParser;

const GdNodeType = enum {
    source,
    extends_statement,
    const_statement,
    signal_statement,
    variable_statement,
    function_definition,
    identifier,
    attribute,
    array,
    string,
    binary_operator,
    arguments,
    attribute_call,
    expression_statement,
    call,
    assignment,
    body,
    if_statement,
    typed_parameter,
    parameters,
    name,
    func,
    conditional_expression,
    pattern_section,
    match,
    match_body,
    match_statement,
    integer,
    @"return",
    return_statement,
    else_clause,
    elif,
    elif_clause,
    get,
    get_body,
    set,
    set_body,
    setget,
    extends,
    @"const",
    signal,
    comparison_operator,
    inferred_type,
    @":=",
    @"var",
    true,
    false,
    type,
    @"if",
    @"else",
    @"(",
    @")",
    @"[",
    @"]",
    @"{",
    @"}",
    @",",
    @".",
    @":",
    @";",
    @"+",
    @"-",
    @"*",
    @"/",
    @"%",
    @"<",
    @">",
    @"<=",
    @">=",
    @"==",
    @"!=",
    @"=",
    @"&&",
    @"||",
    @"!",
    @"\"",
    @"->",
};

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

    for (paths.items) |path| {
        const file = try std.fs.cwd().openFile(path, .{});

        const buf = try arena_allocator.alloc(u8, try file.getEndPos());
        _ = try file.readAll(buf);

        var tree = try ts_parser.parseString(buf);
        defer tree.deinit();

        const root_node = tree.rootNode();

        var cursor = root_node.cursor();
        try depthFirstWalk(&cursor);
    }

    if (unknown_node_types.items.len > 0) {
        std.log.warn("unknown node types", .{});

        for (unknown_node_types.items) |node_type| {
            std.log.warn("{s}", .{node_type});
        }
    }
}

fn depthFirstWalk(cursor: *ts.TSTreeCursor) !void {
    const current_node = cursor.currentNode();
    const node_type = current_node.getTypeAsEnum(GdNodeType) catch @panic("unknown node type");

    if (node_type) |nt| {
        if (current_node.isNamed()) {
            std.log.debug("{}, {s}", .{ nt, current_node.text() });
        }
    } else {
        try unknown_node_types.append(current_node.getTypeAsString());
    }

    if (cursor.gotoFirstChild()) {
        try depthFirstWalk(cursor);
        _ = cursor.gotoParent();
    }

    while (cursor.gotoNextSibling()) {
        try depthFirstWalk(cursor);
    }
}
