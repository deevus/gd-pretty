const std = @import("std");
const tree_sitter = @import("tree-sitter");

const assert = std.debug.assert;
const formatter = @import("formatter.zig");
const enums = @import("enums.zig");
const attribute = @import("attribute.zig");
const @"type" = @import("type.zig");
const Context = @import("Context.zig");

const GdWriter = @This();
const Node = tree_sitter.TSNode;
const NodeType = enums.GdNodeType;

out: std.io.AnyWriter,
context: Context,

const Options = struct {
    writer: std.io.AnyWriter,
    context: ?Context = null,
};

pub fn init(options: Options) GdWriter {
    return GdWriter{
        .out = options.writer,
        .context = options.context orelse .{},
    };
}

pub const IndentOptions = struct {
    new_line: bool = false,
    by: u32 = 0,
};

fn writeIndent(self: *GdWriter, options: IndentOptions) !void {
    if (options.by != 0) {
        self.context.indent_level += options.by;
    }

    if (options.new_line) {
        try self.out.writeAll("\n");
    }

    try formatter.writeIndent(self.out, self.context);
}

fn writeTrimmed(self: *GdWriter, node: Node) !void {
    try self.out.writeAll(formatter.trimWhitespace(node.text()));
}

pub fn writeAttribute(self: *GdWriter, node: Node) !void {
    var i: u32 = 0;

    // identifier
    {
        const identifier = node.child(i) orelse unreachable;
        try self.writeIdentifier(identifier);
    }
    i += 1;
}

pub fn writeSubscript(self: *GdWriter, node: Node) !void {
    try @"type".writeSubscript(node, self.out, self.context);
}

pub fn writeType(self: *GdWriter, node: Node) !void {
    try @"type".writeType(node, self.out, self.context);
}

pub fn writeIdentifier(self: *GdWriter, node: Node) !void {
    try self.writeTrimmed(node);
}

pub fn writeCall(self: *GdWriter, node: Node) !void {
    try self.writeTrimmed(node);
}

pub fn writeClassDefinition(self: *GdWriter, node: Node) !void {
    assert(try node.getTypeAsEnum(NodeType) == .class_definition);

    var i: u32 = 0;

    // "class"
    {
        const class_node = node.child(i) orelse @panic("Expected class");
        assert(try class_node.getTypeAsEnum(NodeType) == .class);

        try self.writeTrimmed(class_node);
        try self.out.writeAll(" ");
        i += 1;
    }

    // name
    {
        const name_node = node.child(i) orelse unreachable;
        assert(try name_node.getTypeAsEnum(NodeType) == .name);

        try self.writeIdentifier(name_node);
        i += 1;
    }

    // extends (optional)
    {
        const extends_node = node.child(i).?;
        if (try extends_node.getTypeAsEnum(NodeType) == .extends_statement) {
            try self.out.writeAll(" ");
            try self.writeExtendsStatement(extends_node);
            i += 1;
        }
    }

    // colon
    {
        const colon_node = node.child(i) orelse @panic("Expected colon");
        assert(try colon_node.getTypeAsEnum(NodeType) == .@":");

        try self.writeTrimmed(colon_node);
        try self.out.writeAll("\n");
        i += 1;
    }

    // body
    {
        const body_node = node.child(i) orelse @panic("Expected body");
        assert(try body_node.getTypeAsEnum(NodeType) == .body);

        try self.writeIndent(.{ .by = 1 });
        try self.writeBody(body_node);
        self.context.indent_level -= 1;
    }
}

pub fn writeBody(self: *GdWriter, node: Node) !void {
    assert(try node.getTypeAsEnum(NodeType) == .body);

    var cursor = node.child(0).?.cursor();

    std.debug.print("body child: {s}\n", .{cursor.currentNode().getTypeAsString()});

    try formatter.depthFirstWalk(&cursor, self.out, self.context);
}

pub fn writePassStatement(self: *GdWriter, node: Node) !void {
    assert(try node.getTypeAsEnum(NodeType) == .pass_statement);

    try self.out.writeAll("pass\n");
}

pub fn writeSignalStatement(self: *GdWriter, node: Node) !void {
    assert(try node.getTypeAsEnum(NodeType) == .signal_statement);

    var i: u32 = 0;

    // signal
    {
        const signal_node = node.child(i).?;
        assert(try signal_node.getTypeAsEnum(NodeType) == .signal);

        try self.out.writeAll("signal ");

        i += 1;
    }

    // identifier
    {
        const name_node = node.child(i).?;
        assert(try name_node.getTypeAsEnum(NodeType) == .name);

        try self.writeIdentifier(name_node);

        i += 1;
    }

    // parameters
    {
        const parameters_node = node.child(i).?;
        assert(try parameters_node.getTypeAsEnum(NodeType) == .parameters);

        try self.writeParameters(parameters_node);
    }
}

pub fn writeParameters(self: *GdWriter, node: Node) !void {
    assert(try node.getTypeAsEnum(NodeType) == .parameters);

    try self.out.writeAll("(");
    for (0..node.childCount()) |j| {
        const param = node.child(@intCast(j)) orelse unreachable;
        const param_type = (try param.getTypeAsEnum(NodeType)).?;

        const param_text = formatter.trimWhitespace(param.text());
        switch (param_type) {
            .typed_parameter => {
                try self.out.writeAll(param_text);
            },
            .@"," => try self.out.writeAll(", "),
            .identifier => try self.out.writeAll(param_text),
            .@"(", .@")" => continue,
            else => std.debug.print("unknown param type: {} {s}\n", .{ param_type, param.text() }),
        }
    }
    try self.out.writeAll(")");
}

pub fn writeExtendsStatement(self: *GdWriter, node: Node) !void {
    assert(node.childCount() == 2);

    // extends
    try self.out.writeAll("extends ");
    try self.out.print("{s}", .{formatter.trimWhitespace(node.child(1).?.text())});
}

pub fn writeVariableStatement(self: *GdWriter, node: Node) !void {
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
                        try self.out.writeAll(c.text());
                    } else {
                        try self.out.print("{s} ", .{c.text()});
                    }
                },
                else => try self.out.print("{s} ", .{c.text()}),
            }
        }
    }

    _ = try self.out.write("\n");
}

pub fn writeFunctionDefinition(self: *GdWriter, node: Node) anyerror!void {
    var i: u32 = 0;

    // func keyword
    {
        const func_node = node.child(i) orelse unreachable;
        assert(try func_node.getTypeAsEnum(NodeType) == .func);
        try self.out.writeAll("func");
    }
    i += 1;

    // optional name
    {
        if (try node.child(i).?.getTypeAsEnum(NodeType) == .name) {
            const text = formatter.trimWhitespace(node.child(i).?.text());
            try self.out.writeAll(" ");
            try self.out.writeAll(text);
            i += 1;
        }
    }

    // parameters
    {
        const params_node = node.child(i) orelse unreachable;
        assert(try params_node.getTypeAsEnum(NodeType) == .parameters);

        try self.out.writeAll("(");
        for (0..params_node.childCount()) |j| {
            const param = params_node.child(@intCast(j)) orelse unreachable;
            const param_type = (try param.getTypeAsEnum(NodeType)).?;

            const param_text = formatter.trimWhitespace(param.text());
            switch (param_type) {
                .typed_parameter => {
                    try self.out.writeAll(param_text);
                },
                .@"," => try self.out.writeAll(", "),
                .identifier => try self.out.writeAll(param_text),
                .@"(", .@")" => continue,
                else => std.debug.print("unknown param type: {} {s}\n", .{ param_type, param.text() }),
            }
        }
        try self.out.writeAll(")");
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

            try self.out.writeAll(" -> ");
            try @"type".writeType(type_node, self.out, self.context);
        }
    }

    // colon
    {
        const colon_node = node.child(i) orelse unreachable;
        assert(try colon_node.getTypeAsEnum(NodeType) == .@":");
        try self.out.writeAll(":\n");
    }
    i += 1;

    // body
    {
        const body_node = node.child(i) orelse unreachable;
        assert(try body_node.getTypeAsEnum(NodeType) == .body);

        var body_cursor = body_node.child(0).?.cursor();
        try formatter.depthFirstWalk(&body_cursor, self.out, self.context.indent());
    }
}

pub fn writeReturnStatement(self: *GdWriter, node: Node) anyerror!void {
    const return_node = node.child(0) orelse unreachable;
    assert(try return_node.getTypeAsEnum(NodeType) == .@"return");
    try self.out.writeAll("return ");

    var next_node = node.child(1) orelse return;

    var cursor = next_node.cursor();
    try formatter.depthFirstWalk(&cursor, self.out, self.context);
}
