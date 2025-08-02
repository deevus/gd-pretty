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
const CountingWriter = std.io.CountingWriter(std.io.AnyWriter);

pub const Error = error{
    MalformedAST,
    UnexpectedNodeType,
    MissingRequiredChild,
    InvalidNodeStructure,
    MaxWidthExceeded,
} || std.io.AnyWriter.Error;

counting_writer: CountingWriter,
current_line_start: u64 = 0,
context: Context,

const Options = struct {
    writer: std.io.AnyWriter,
    context: ?Context = null,
};

pub fn init(options: Options) GdWriter {
    return GdWriter{
        .counting_writer = std.io.countingWriter(options.writer),
        .current_line_start = 0,
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
        try self.writeNewline();
    }

    try formatter.writeIndent(self.counting_writer.writer(), self.context);
}

fn getCurrentLineWidth(self: *GdWriter) u32 {
    return @intCast(self.counting_writer.bytes_written - self.current_line_start);
}

fn writeNewline(self: *GdWriter) !void {
    try self.counting_writer.writer().writeAll("\n");
    self.current_line_start = self.counting_writer.bytes_written;
}

fn writeTrimmed(self: *GdWriter, node: Node) !void {
    const text = formatter.trimWhitespace(node.text());
    try self.write(text, .{});
}

const WriteOptions = struct {
    check_max_width: bool = true,
};

fn write(self: *GdWriter, text: []const u8, options: WriteOptions) Error!void {
    _ = options; // autofix
    var writer = self.counting_writer.writer();
    try writer.writeAll(text);
}

pub fn writeAttribute(self: *GdWriter, node: Node) Error!void {
    var i: u32 = 0;

    // identifier
    {
        const identifier = node.child(i) orelse return Error.MissingRequiredChild;
        try self.writeIdentifier(identifier);
    }
    i += 1;
}

pub fn writeSubscript(self: *GdWriter, node: Node) !void {
    try @"type".writeSubscript(node, self.counting_writer.writer(), self.context);
}

pub fn writeType(self: *GdWriter, node: Node) !void {
    try @"type".writeType(node, self.counting_writer.writer(), self.context);
}

pub fn writeIdentifier(self: *GdWriter, node: Node) !void {
    try self.writeTrimmed(node);
}

pub fn writeCall(self: *GdWriter, node: Node) !void {
    try self.writeTrimmed(node);
}

pub fn writeClassDefinition(self: *GdWriter, node: Node) Error!void {
    assert(try node.getTypeAsEnum(NodeType) == .class_definition);

    var i: u32 = 0;

    // "class"
    {
        const class_node = node.child(i) orelse return Error.MissingRequiredChild;
        assert(try class_node.getTypeAsEnum(NodeType) == .class);

        try self.writeTrimmed(class_node);
        try self.write(" ", .{});
        i += 1;
    }

    // name
    {
        const name_node = node.child(i) orelse return Error.MissingRequiredChild;
        assert(try name_node.getTypeAsEnum(NodeType) == .name);

        try self.writeIdentifier(name_node);
        i += 1;
    }

    // extends (optional)
    {
        const extends_node = node.child(i).?;
        if (try extends_node.getTypeAsEnum(NodeType) == .extends_statement) {
            try self.write(" ", .{});
            try self.writeExtendsStatement(extends_node);
            i += 1;
        }
    }

    // colon
    {
        const colon_node = node.child(i) orelse return Error.MissingRequiredChild;
        assert(try colon_node.getTypeAsEnum(NodeType) == .@":");

        try self.writeTrimmed(colon_node);
        try self.writeNewline();
        i += 1;
    }

    // body
    {
        const body_node = node.child(i) orelse return Error.MissingRequiredChild;
        assert(try body_node.getTypeAsEnum(NodeType) == .body);

        try self.writeIndent(.{ .by = 1 });
        try self.writeBody(body_node);
        self.context.indent_level -= 1;
    }
}

pub fn writeBody(self: *GdWriter, node: Node) !void {
    assert(try node.getTypeAsEnum(NodeType) == .body);
    var cursor = node.child(0).?.cursor();
    try formatter.depthFirstWalk(&cursor, self.counting_writer.writer().any(), self.context);
}

pub fn writePassStatement(self: *GdWriter, node: Node) !void {
    assert(try node.getTypeAsEnum(NodeType) == .pass_statement);

    try self.write("pass\n", .{});
}

pub fn writeSignalStatement(self: *GdWriter, node: Node) !void {
    assert(try node.getTypeAsEnum(NodeType) == .signal_statement);

    var i: u32 = 0;

    // signal
    {
        const signal_node = node.child(i).?;
        assert(try signal_node.getTypeAsEnum(NodeType) == .signal);

        try self.writeTrimmed(signal_node);
        try self.write(" ", .{});

        i += 1;
    }

    // identifier
    {
        const name_node = node.child(i).?;
        assert(try name_node.getTypeAsEnum(NodeType) == .name);

        try self.writeIdentifier(name_node);

        i += 1;
    }

    // parameters (optional)
    {
        if (node.child(i)) |parameters_node| {
            assert(try parameters_node.getTypeAsEnum(NodeType) == .parameters);
            try self.writeParameters(parameters_node);
            i += 1;
        }
    }

    try self.writeNewline();
}

pub fn writeParameters(self: *GdWriter, node: Node) Error!void {
    assert(try node.getTypeAsEnum(NodeType) == .parameters);

    try self.write("(", .{});
    for (0..node.childCount()) |j| {
        const param = node.child(@intCast(j)) orelse return Error.MissingRequiredChild;
        const param_type = (try param.getTypeAsEnum(NodeType)).?;

        const param_text = formatter.trimWhitespace(param.text());
        switch (param_type) {
            .typed_parameter => {
                try self.write(param_text, .{});
            },
            .@"," => try self.write(", ", .{}),
            .identifier => try self.write(param_text, .{}),
            .@"(", .@")" => continue,
            else => std.debug.print("unknown param type: {} {s}\n", .{ param_type, param.text() }),
        }
    }
    try self.write(")", .{});
}

pub fn writeExtendsStatement(self: *GdWriter, node: Node) !void {
    assert(node.childCount() == 2);

    // extends
    try self.write("extends ", .{});
    try self.write(formatter.trimWhitespace(node.child(1).?.text()), .{});
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
                        try self.write(c.text(), .{});
                    } else {
                        try self.write(c.text(), .{});
                        try self.write(" ", .{});
                    }
                },
                .@"var" => {
                    try self.write("var ", .{});
                },
                .@"=" => {
                    try self.write("= ", .{});
                },
                .binary_operator => {
                    // Process binary expressions properly
                    var cursor = c.cursor();
                    try formatter.depthFirstWalk(&cursor, self.counting_writer.writer().any(), self.context);
                },
                else => {
                    // For expressions and other complex nodes, traverse them properly
                    const node_text = c.text();
                    // Check if this might be an expression
                    if (std.mem.indexOf(u8, node_text, "+") != null or
                        std.mem.indexOf(u8, node_text, "-") != null or
                        std.mem.indexOf(u8, node_text, "*") != null or
                        std.mem.indexOf(u8, node_text, "/") != null)
                    {
                        var cursor = c.cursor();
                        try formatter.depthFirstWalk(&cursor, self.counting_writer.writer().any(), self.context);
                    } else {
                        try self.write(c.text(), .{});
                        try self.write(" ", .{});
                    }
                },
            }
        }
    }

    try self.writeNewline();
}

pub fn writeFunctionDefinition(self: *GdWriter, node: Node) Error!void {
    var i: u32 = 0;

    // func keyword
    {
        const func_node = node.child(i) orelse return Error.MissingRequiredChild;
        assert(try func_node.getTypeAsEnum(NodeType) == .func);
        try self.write("func", .{});
    }
    i += 1;

    // optional name
    {
        if (try node.child(i).?.getTypeAsEnum(NodeType) == .name) {
            const text = formatter.trimWhitespace(node.child(i).?.text());
            try self.write(" ", .{});
            try self.write(text, .{});
            i += 1;
        }
    }

    // parameters
    {
        const params_node = node.child(i) orelse return Error.MissingRequiredChild;
        assert(try params_node.getTypeAsEnum(NodeType) == .parameters);

        try self.write("(", .{});
        for (0..params_node.childCount()) |j| {
            const param = params_node.child(@intCast(j)) orelse return Error.MissingRequiredChild;
            const param_type = (try param.getTypeAsEnum(NodeType)).?;

            const param_text = formatter.trimWhitespace(param.text());
            switch (param_type) {
                .typed_parameter => {
                    try self.write(param_text, .{});
                },
                .@"," => try self.write(", ", .{}),
                .identifier => try self.write(param_text, .{}),
                .@"(", .@")" => continue,
                else => std.debug.print("unknown param type: {} {s}\n", .{ param_type, param.text() }),
            }
        }
        try self.write(")", .{});
    }
    i += 1;

    // return type (optional)
    {
        // arrow
        const return_arrow_node = node.child(i) orelse return Error.MissingRequiredChild;
        if (try return_arrow_node.getTypeAsEnum(NodeType) == .@"->") {
            i += 1;

            // type
            const type_node = node.child(i) orelse return Error.MissingRequiredChild;
            assert(try type_node.getTypeAsEnum(NodeType) == .type);
            i += 1;

            try self.write(" -> ", .{});
            try @"type".writeType(type_node, self.counting_writer.writer(), self.context);
        }
    }

    // colon
    {
        const colon_node = node.child(i) orelse return Error.MissingRequiredChild;
        assert(try colon_node.getTypeAsEnum(NodeType) == .@":");
        try self.write(":\n", .{});
    }
    i += 1;

    // body
    {
        const body_node = node.child(i) orelse return Error.MissingRequiredChild;
        assert(try body_node.getTypeAsEnum(NodeType) == .body);

        var body_cursor = body_node.child(0).?.cursor();
        try formatter.depthFirstWalk(&body_cursor, self.counting_writer.writer().any(), self.context.indent());
    }
}

pub fn writeReturnStatement(self: *GdWriter, node: Node) Error!void {
    const return_node = node.child(0) orelse return Error.MissingRequiredChild;
    assert(try return_node.getTypeAsEnum(NodeType) == .@"return");
    try self.write("return ", .{});

    var next_node = node.child(1) orelse return;

    var cursor = next_node.cursor();
    try formatter.depthFirstWalk(&cursor, self.counting_writer.writer().any(), self.context);
}

pub fn writeClassNameStatement(self: *GdWriter, node: Node) Error!void {
    const class_name_node = node.child(0) orelse return Error.MissingRequiredChild;
    assert(try class_name_node.getTypeAsEnum(NodeType) == .class_name);
    try self.writeTrimmed(class_name_node);
    try self.write(" ", .{});

    const name_node = node.child(1) orelse return Error.MissingRequiredChild;
    assert(try name_node.getTypeAsEnum(NodeType) == .name);
    try self.writeTrimmed(name_node);
    try self.writeNewline();
}

// ============================================================================
// STUB METHODS - Need implementation for full GDScript support
// ============================================================================

// Critical Language Features
pub fn writeSource(self: *GdWriter, node: Node) anyerror!void {
    // Source node is the root - need to traverse its children
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (i > 0) {
            try self.writeNewline();
        }
        const child = node.child(i).?;
        var cursor = child.cursor();
        try formatter.depthFirstWalk(&cursor, self.counting_writer.writer().any(), self.context);
    }
}

pub fn writeConstStatement(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement const declarations (const VAR = value)
    try self.writeTrimmed(node);
}

pub fn writeIfStatement(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement if statements with proper indentation
    try self.writeTrimmed(node);
}

pub fn writeForStatement(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement for loops with proper indentation
    try self.writeTrimmed(node);
}

pub fn writeAssignment(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement variable assignments (var = value)
    try self.writeTrimmed(node);
}

pub fn writeAugmentedAssignment(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement compound assignments (+=, -=, etc.)
    try self.writeTrimmed(node);
}

pub fn writeExpressionStatement(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement expression statements
    try self.writeTrimmed(node);
}

pub fn writeMatchStatement(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement match statements with proper indentation
    try self.writeTrimmed(node);
}

pub fn writeMatchBody(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement match body with proper indentation
    try self.writeTrimmed(node);
}

pub fn writePatternSection(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement match patterns
    try self.writeTrimmed(node);
}

pub fn writeElseClause(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement else clauses with proper indentation
    try self.writeTrimmed(node);
}

pub fn writeElifClause(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement elif clauses with proper indentation
    try self.writeTrimmed(node);
}

pub fn writeLambda(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement lambda expressions
    try self.writeTrimmed(node);
}

pub fn writeGetBody(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement getter method bodies
    try self.writeTrimmed(node);
}

pub fn writeSetBody(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement setter method bodies
    try self.writeTrimmed(node);
}

pub fn writeSetget(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement setget property declarations
    try self.writeTrimmed(node);
}

pub fn writeGetNode(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement get_node expressions ($Node)
    try self.writeTrimmed(node);
}

// Data Types and Literals
pub fn writeArray(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement array literals [1, 2, 3] with proper spacing
    try self.writeTrimmed(node);
}

pub fn writeString(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement string literals with proper escaping
    try self.writeTrimmed(node);
}

pub fn writeInteger(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement integer literals
    try self.writeTrimmed(node);
}

pub fn writeFloat(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement float literals
    try self.writeTrimmed(node);
}

pub fn writeDictionary(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement dictionary literals {key: value} with proper spacing
    try self.writeTrimmed(node);
}

pub fn writePair(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement key-value pairs in dictionaries
    try self.writeTrimmed(node);
}

pub fn writeTrue(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement boolean true literal
    try self.writeTrimmed(node);
}

pub fn writeFalse(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement boolean false literal
    try self.writeTrimmed(node);
}

// Expressions and Operations
pub fn writeBinaryOperator(self: *GdWriter, node: Node) anyerror!void {
    // Binary expressions have structure: left_expr operator right_expr
    assert(node.childCount() == 3);

    // Debug output removed

    // Try single-line format first
    self.writeBinaryOperatorNormal(node) catch |err| switch (err) {
        Error.MaxWidthExceeded => {
            // Fallback to multiline format
            return self.writeBinaryOperatorMultiline(node);
        },
        else => return err,
    };
}

fn writeBinaryOperatorNormal(self: *GdWriter, node: Node) Error!void {
    const left = node.child(0).?;
    const op = node.child(1).?;
    const right = node.child(2).?;

    // Check total width that would be consumed by this entire binary expression
    const full_text = node.text();
    const current_width = self.getCurrentLineWidth();

    // If the entire expression would exceed the limit, trigger multiline mode
    if (current_width + full_text.len > self.context.max_width) {
        // Triggering multiline format due to width exceeded
        return Error.MaxWidthExceeded;
    }

    // Use unchecked writes since we've already verified the total width
    // Write left operand
    var cursor = left.cursor();
    try formatter.depthFirstWalk(&cursor, self.counting_writer.writer().any(), self.context);

    // Write operator with spaces
    try self.write(" ", .{});
    try self.write(op.text(), .{});
    try self.write(" ", .{});

    // Write right operand
    cursor = right.cursor();
    try formatter.depthFirstWalk(&cursor, self.counting_writer.writer().any(), self.context);
}

fn writeBinaryOperatorMultiline(self: *GdWriter, node: Node) !void {
    const left = node.child(0).?;
    const op = node.child(1).?;
    const right = node.child(2).?;

    // Write left operand
    var cursor = left.cursor();
    try formatter.depthFirstWalk(&cursor, self.counting_writer.writer().any(), self.context);

    // Write operator without trailing space
    try self.write(" ", .{});
    try self.write(op.text(), .{});

    // Newline and indented right operand
    try self.writeNewline();
    try self.writeIndent(.{ .new_line = false });
    try self.writeIndent(.{ .new_line = false }); // Double indent for continuation

    // Write right operand
    cursor = right.cursor();
    try formatter.depthFirstWalk(&cursor, self.counting_writer.writer().any(), self.context);
}

pub fn writeComparisonOperator(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement comparison operations with proper spacing
    try self.writeTrimmed(node);
}

pub fn writeConditionalExpression(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement ternary/conditional expressions
    try self.writeTrimmed(node);
}

pub fn writeAttributeCall(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement method calls on objects
    try self.writeTrimmed(node);
}

pub fn writeArguments(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement function call arguments with proper spacing
    try self.writeTrimmed(node);
}

pub fn writeParenthesizedExpression(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement expressions in parentheses
    try self.writeTrimmed(node);
}

// Type System
pub fn writeInferredType(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement type inference markers (:=)
    try self.writeTrimmed(node);
}

pub fn writeTypedParameter(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement function parameters with types
    try self.writeTrimmed(node);
}

pub fn writeAnnotation(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement single annotation (@export, @onready, etc.)
    try self.writeTrimmed(node);
}

pub fn writeAnnotations(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement multiple annotations
    try self.writeTrimmed(node);
}

// Keywords (many may be handled by their parent nodes)
pub fn writeSignal(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement signal keyword
    try self.writeTrimmed(node);
}

pub fn writePass(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement pass keyword
    try self.writeTrimmed(node);
}

pub fn writeFunc(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement func keyword
    try self.writeTrimmed(node);
}

pub fn writeExtends(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement extends keyword
    try self.writeTrimmed(node);
}

pub fn writeConst(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement const keyword
    try self.writeTrimmed(node);
}

pub fn writeVar(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement var keyword
    try self.writeTrimmed(node);
}

pub fn writeFor(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement for keyword
    try self.writeTrimmed(node);
}

pub fn writeIn(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement in keyword
    try self.writeTrimmed(node);
}

pub fn writeIf(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement if keyword
    try self.writeTrimmed(node);
}

pub fn writeElse(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement else keyword
    try self.writeTrimmed(node);
}

pub fn writeElif(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement elif keyword
    try self.writeTrimmed(node);
}

pub fn writeReturn(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement return keyword
    try self.writeTrimmed(node);
}

pub fn writeGet(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement get keyword
    try self.writeTrimmed(node);
}

pub fn writeSet(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement set keyword
    try self.writeTrimmed(node);
}

pub fn writeMatch(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement match keyword
    try self.writeTrimmed(node);
}

pub fn writeClassName(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement class_name keyword
    try self.writeTrimmed(node);
}

pub fn writeClass(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement class keyword
    try self.writeTrimmed(node);
}

// Utility Methods
pub fn writeComment(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement comment preservation with proper spacing
    try self.writeTrimmed(node);
}

pub fn writeName(self: *GdWriter, node: Node) anyerror!void {
    // TODO: Implement name nodes (may be handled by writeIdentifier)
    try self.writeTrimmed(node);
}

// Punctuation and Operators (low priority - often just pass through)
pub fn writeAt(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writeOpenParen(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writeCloseParen(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writeOpenBracket(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writeCloseBracket(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writeOpenBrace(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writeCloseBrace(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writeComma(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writeDot(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writeColon(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writeSemicolon(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writePlus(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writePlusEquals(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writeMinus(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writeMultiply(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writeDivide(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writeModulo(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writeLessThan(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writeGreaterThan(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writeLessEqual(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writeGreaterEqual(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writeEquals(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writeNotEquals(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writeAssign(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writeLogicalAnd(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writeLogicalOr(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writeLogicalNot(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writeQuote(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writeArrow(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}

pub fn writeColonEquals(self: *GdWriter, node: Node) anyerror!void {
    try self.writeTrimmed(node);
}
