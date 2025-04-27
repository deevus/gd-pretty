const std = @import("std");
const TSNode = @import("tree-sitter").TSNode;
const Context = @import("Context.zig");
const formatter = @import("formatter.zig");
const enums = @import("enums.zig");
const @"type" = @import("type.zig");

const NodeType = enums.GdNodeType;
const assert = std.debug.assert;

pub fn writeExtendsStatement(node: TSNode, writer: anytype, context: Context) anyerror!void {
    _ = context;

    assert(node.childCount() == 2);

    // extends
    try writer.writeAll("extends ");
    try writer.print("{s}", .{formatter.trimWhitespace(node.child(1).?.text())});
}

pub fn writeVariableStatement(node: TSNode, writer: anytype, context: Context) anyerror!void {
    _ = context;

    for (0..node.childCount()) |i| {
        const prev_child = if (i > 0) node.child(@intCast(i - 1)) else null;
        _ = prev_child;
        const child = node.child(@intCast(i));
        const next_child = node.child(@intCast(i + 1));

        if (child) |c| {
            const nt = (try c.getTypeAsEnum(enums.GdNodeType)).?;

            switch (nt) {
                .name => {
                    const next_child_is_type = blk: {
                        if (next_child) |nc| {
                            const nc_type = (try nc.getTypeAsEnum(enums.GdNodeType)).?;

                            if (nc_type == .@":") {
                                break :blk true;
                            }
                        }

                        break :blk false;
                    };

                    if (next_child_is_type) {
                        try writer.writeAll(c.text());
                    } else {
                        try writer.print("{s} ", .{c.text()});
                    }
                },
                else => try writer.print("{s} ", .{c.text()}),
            }
        }
    }

    _ = try writer.write("\n");
}

pub fn writeFunctionDefinition(node: TSNode, writer: anytype, context: Context) anyerror!void {
    var i: u32 = 0;

    // func keyword
    {
        const func_node = node.child(i) orelse unreachable;
        assert(try func_node.getTypeAsEnum(NodeType) == .func);
        try writer.writeAll("func");
    }
    i += 1;

    // optional name
    {
        if (try node.child(i).?.getTypeAsEnum(NodeType) == .name) {
            const text = formatter.trimWhitespace(node.child(i).?.text());
            try writer.writeAll(" ");
            try writer.writeAll(text);
            i += 1;
        }
    }

    // parameters
    {
        const params_node = node.child(i) orelse unreachable;
        assert(try params_node.getTypeAsEnum(NodeType) == .parameters);

        try writer.writeAll("(");
        for (0..params_node.childCount()) |j| {
            const param = params_node.child(@intCast(j)) orelse unreachable;
            const param_type = (try param.getTypeAsEnum(NodeType)).?;

            const param_text = formatter.trimWhitespace(param.text());
            switch (param_type) {
                .typed_parameter => {
                    try writer.writeAll(param_text);
                },
                .@"," => try writer.writeAll(", "),
                .identifier => try writer.writeAll(param_text),
                .@"(", .@")" => continue,
                else => std.debug.print("unknown param type: {} {s}\n", .{ param_type, param.text() }),
            }
        }
        try writer.writeAll(")");
    }
    i += 1;

    // return type (optional)
    {
        // arrow
        const return_arrow_node = node.child(i) orelse unreachable;
        if (try return_arrow_node.getTypeAsEnum(NodeType) == .@"->") {
            i += 1;

            // type
            const type_node = node.child(i) orelse unreachable;
            assert(try type_node.getTypeAsEnum(NodeType) == .type);
            i += 1;

            try writer.writeAll(" -> ");
            try @"type".writeType(type_node, writer, context);
        }
    }

    // colon
    {
        const colon_node = node.child(i) orelse unreachable;
        assert(try colon_node.getTypeAsEnum(NodeType) == .@":");
        try writer.writeAll(":\n");
    }
    i += 1;

    // body
    {
        const body_node = node.child(i) orelse unreachable;
        assert(try body_node.getTypeAsEnum(NodeType) == .body);

        var body_cursor = body_node.child(0).?.cursor();
        try formatter.depthFirstWalk(&body_cursor, writer, context.indent());
    }
}

pub fn writeReturnStatement(node: TSNode, writer: anytype, context: Context) anyerror!void {
    const return_node = node.child(0) orelse unreachable;
    assert(try return_node.getTypeAsEnum(NodeType) == .@"return");
    try writer.writeAll("return ");

    var next_node = node.child(1) orelse return;

    var cursor = next_node.cursor();
    try formatter.depthFirstWalk(&cursor, writer, context);
}
