const GdWriter = @This();

pub const Error = error{
    MalformedAST,
    UnexpectedNodeType,
    MissingRequiredChild,
    InvalidNodeStructure,
    NoSpaceLeft,
} || Writer.Error;

out: *Writer,
context: Context,

const Options = struct {
    writer: *Writer,
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

fn writeIndent(self: *GdWriter, options: IndentOptions) Error!void {
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

pub fn writeAttribute(self: *GdWriter, node: Node) Error!void {
    var i: u32 = 0;

    // identifier
    {
        const identifier = node.child(i) orelse return Error.MissingRequiredChild;
        try self.writeIdentifier(identifier);
    }
    i += 1;
}

pub fn writeSubscript(self: *GdWriter, node: Node) Error!void {
    try @"type".writeSubscript(node, self.out, self.context);
}

pub fn writeType(self: *GdWriter, node: Node) Error!void {
    try @"type".writeType(node, self.out, self.context);
}

pub fn writeIdentifier(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeCall(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeClassDefinition(self: *GdWriter, node: Node) Error!void {
    assert(node.getTypeAsEnum(NodeType) == .class_definition);

    var i: u32 = 0;

    // "class"
    {
        const class_node = node.child(i) orelse return Error.MissingRequiredChild;
        assert(class_node.getTypeAsEnum(NodeType) == .class);

        try self.writeTrimmed(class_node);
        try self.out.writeAll(" ");
        i += 1;
    }

    // name
    {
        const name_node = node.child(i) orelse return Error.MissingRequiredChild;
        assert(name_node.getTypeAsEnum(NodeType) == .name);

        try self.writeIdentifier(name_node);
        i += 1;
    }

    // extends (optional)
    {
        const extends_node = node.child(i).?;
        if (extends_node.getTypeAsEnum(NodeType) == .extends_statement) {
            try self.out.writeAll(" ");
            try self.writeExtendsStatement(extends_node);
            i += 1;
        }
    }

    // colon
    {
        const colon_node = node.child(i) orelse return Error.MissingRequiredChild;
        assert(colon_node.getTypeAsEnum(NodeType) == .@":");

        try self.writeTrimmed(colon_node);
        try self.out.writeAll("\n");
        i += 1;
    }

    // body
    {
        const body_node = node.child(i) orelse return Error.MissingRequiredChild;
        assert(body_node.getTypeAsEnum(NodeType) == .body);

        try self.writeIndent(.{ .by = 1 });
        try self.writeBody(body_node);
        self.context.indent_level -= 1;
    }
}

pub fn writeBody(self: *GdWriter, node: Node) Error!void {
    assert(node.getTypeAsEnum(NodeType) == .body);
    var cursor = node.child(0).?.cursor();
    try formatter.depthFirstWalk(&cursor, self.out, self.context);
}

pub fn writePassStatement(self: *GdWriter, node: Node) Error!void {
    assert(node.getTypeAsEnum(NodeType) == .pass_statement);

    try self.out.writeAll("pass\n");
}

pub fn writeSignalStatement(self: *GdWriter, node: Node) Error!void {
    assert(node.getTypeAsEnum(NodeType) == .signal_statement);

    var i: u32 = 0;

    // signal
    {
        const signal_node = node.child(i).?;
        assert(signal_node.getTypeAsEnum(NodeType) == .signal);

        try self.writeTrimmed(signal_node);
        try self.out.writeAll(" ");

        i += 1;
    }

    // identifier
    {
        const name_node = node.child(i).?;
        assert(name_node.getTypeAsEnum(NodeType) == .name);

        try self.writeIdentifier(name_node);

        i += 1;
    }

    // parameters (optional)
    {
        if (node.child(i)) |parameters_node| {
            assert(parameters_node.getTypeAsEnum(NodeType) == .parameters);
            try self.writeParameters(parameters_node);
            i += 1;
        }
    }

    try self.out.writeAll("\n");
}

pub fn writeParameters(self: *GdWriter, node: Node) Error!void {
    assert(node.getTypeAsEnum(NodeType) == .parameters);

    try self.out.writeAll("(");
    for (0..node.childCount()) |j| {
        const param = node.child(@intCast(j)) orelse return Error.MissingRequiredChild;
        const param_type = (param.getTypeAsEnum(NodeType)).?;

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

pub fn writeExtendsStatement(self: *GdWriter, node: Node) Error!void {
    assert(node.childCount() == 2);

    // extends
    try self.out.writeAll("extends ");
    try self.out.print("{s}", .{formatter.trimWhitespace(node.child(1).?.text())});
}

pub fn writeVariableStatement(self: *GdWriter, node: Node) Error!void {
    for (0..node.childCount()) |i| {
        const prev_child = if (i > 0) node.child(@intCast(i - 1)) else null;
        _ = prev_child;
        const child = node.child(@intCast(i));
        const next_child = node.child(@intCast(i + 1));

        if (child) |c| {
            const nt = (c.getTypeAsEnum(enums.GdNodeType)).?;

            switch (nt) {
                .name => {
                    const next_child_is_type = blk: {
                        if (next_child) |nc| {
                            const nc_type = (nc.getTypeAsEnum(enums.GdNodeType)).?;

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

pub fn writeFunctionDefinition(self: *GdWriter, node: Node) Error!void {
    var i: u32 = 0;

    // func keyword
    {
        const func_node = node.child(i) orelse return Error.MissingRequiredChild;
        assert(func_node.getTypeAsEnum(NodeType) == .func);
        try self.out.writeAll("func");
    }
    i += 1;

    // optional name
    {
        if (node.child(i).?.getTypeAsEnum(NodeType) == .name) {
            const text = formatter.trimWhitespace(node.child(i).?.text());
            try self.out.writeAll(" ");
            try self.out.writeAll(text);
            i += 1;
        }
    }

    // parameters
    {
        const params_node = node.child(i) orelse return Error.MissingRequiredChild;
        assert(params_node.getTypeAsEnum(NodeType) == .parameters);

        try self.out.writeAll("(");
        for (0..params_node.childCount()) |j| {
            const param = params_node.child(@intCast(j)) orelse return Error.MissingRequiredChild;
            const param_type = (param.getTypeAsEnum(NodeType)).?;

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
        const return_arrow_node = node.child(i) orelse return Error.MissingRequiredChild;
        if (return_arrow_node.getTypeAsEnum(NodeType) == .@"->") {
            i += 1;

            // type
            const type_node = node.child(i) orelse return Error.MissingRequiredChild;
            assert(type_node.getTypeAsEnum(NodeType) == .type);
            i += 1;

            try self.out.writeAll(" -> ");
            try @"type".writeType(type_node, self.out, self.context);
        }
    }

    // colon
    {
        const colon_node = node.child(i) orelse return Error.MissingRequiredChild;
        assert(colon_node.getTypeAsEnum(NodeType) == .@":");
        try self.out.writeAll(":\n");
    }
    i += 1;

    // body
    {
        const body_node = node.child(i) orelse return Error.MissingRequiredChild;
        assert(body_node.getTypeAsEnum(NodeType) == .body);

        var body_cursor = body_node.child(0).?.cursor();
        try formatter.depthFirstWalk(&body_cursor, self.out, self.context.indent());
    }
}

pub fn writeReturnStatement(self: *GdWriter, node: Node) Error!void {
    const return_node = node.child(0) orelse return Error.MissingRequiredChild;
    assert(return_node.getTypeAsEnum(NodeType) == .@"return");
    try self.out.writeAll("return ");

    var next_node = node.child(1) orelse return;

    var cursor = next_node.cursor();
    try formatter.depthFirstWalk(&cursor, self.out, self.context);
}

pub fn writeClassNameStatement(self: *GdWriter, node: Node) Error!void {
    const class_name_node = node.child(0) orelse return Error.MissingRequiredChild;
    assert(class_name_node.getTypeAsEnum(NodeType) == .class_name);
    try self.writeTrimmed(class_name_node);
    try self.out.writeAll(" ");

    const name_node = node.child(1) orelse return Error.MissingRequiredChild;
    assert(name_node.getTypeAsEnum(NodeType) == .name);
    try self.writeTrimmed(name_node);
    try self.out.writeAll("\n");
}

// ============================================================================
// STUB METHODS - Need implementation for full GDScript support
// ============================================================================

// Critical Language Features
pub fn writeSource(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement source node handling (root of the AST)
    try self.writeTrimmed(node);
}

pub fn writeConstStatement(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement const declarations (const VAR = value)
    try self.writeTrimmed(node);
}

pub fn writeIfStatement(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement if statements with proper indentation
    try self.writeTrimmed(node);
}

pub fn writeForStatement(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement for loops with proper indentation
    try self.writeTrimmed(node);
}

pub fn writeAssignment(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement variable assignments (var = value)
    try self.writeTrimmed(node);
}

pub fn writeAugmentedAssignment(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement compound assignments (+=, -=, etc.)
    try self.writeTrimmed(node);
}

pub fn writeExpressionStatement(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement expression statements
    try self.writeTrimmed(node);
}

pub fn writeMatchStatement(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement match statements with proper indentation
    try self.writeTrimmed(node);
}

pub fn writeMatchBody(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement match body with proper indentation
    try self.writeTrimmed(node);
}

pub fn writePatternSection(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement match patterns
    try self.writeTrimmed(node);
}

pub fn writeElseClause(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement else clauses with proper indentation
    try self.writeTrimmed(node);
}

pub fn writeElifClause(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement elif clauses with proper indentation
    try self.writeTrimmed(node);
}

pub fn writeLambda(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement lambda expressions
    try self.writeTrimmed(node);
}

pub fn writeGetBody(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement getter method bodies
    try self.writeTrimmed(node);
}

pub fn writeSetBody(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement setter method bodies
    try self.writeTrimmed(node);
}

pub fn writeSetget(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement setget property declarations
    try self.writeTrimmed(node);
}

pub fn writeGetNode(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement get_node expressions ($Node)
    try self.writeTrimmed(node);
}

// Data Types and Literals
pub fn writeArray(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement array literals [1, 2, 3] with proper spacing
    try self.writeTrimmed(node);
}

pub fn writeString(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement string literals with proper escaping
    try self.writeTrimmed(node);
}

pub fn writeInteger(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement integer literals
    try self.writeTrimmed(node);
}

pub fn writeFloat(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement float literals
    try self.writeTrimmed(node);
}

pub fn writeDictionary(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement dictionary literals {key: value} with proper spacing
    try self.writeTrimmed(node);
}

pub fn writePair(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement key-value pairs in dictionaries
    try self.writeTrimmed(node);
}

pub fn writeTrue(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement boolean true literal
    try self.writeTrimmed(node);
}

pub fn writeFalse(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement boolean false literal
    try self.writeTrimmed(node);
}

// Expressions and Operations
pub fn writeBinaryOperator(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement binary operations with proper spacing
    try self.writeTrimmed(node);
}

pub fn writeComparisonOperator(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement comparison operations with proper spacing
    try self.writeTrimmed(node);
}

pub fn writeConditionalExpression(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement ternary/conditional expressions
    try self.writeTrimmed(node);
}

pub fn writeAttributeCall(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement method calls on objects
    try self.writeTrimmed(node);
}

pub fn writeArguments(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement function call arguments with proper spacing
    try self.writeTrimmed(node);
}

pub fn writeParenthesizedExpression(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement expressions in parentheses
    try self.writeTrimmed(node);
}

// Type System
pub fn writeInferredType(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement type inference markers (:=)
    try self.writeTrimmed(node);
}

pub fn writeTypedParameter(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement function parameters with types
    try self.writeTrimmed(node);
}

pub fn writeAnnotation(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement single annotation (@export, @onready, etc.)
    try self.writeTrimmed(node);
}

pub fn writeAnnotations(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement multiple annotations
    try self.writeTrimmed(node);
}

// Keywords (many may be handled by their parent nodes)
pub fn writeSignal(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement signal keyword
    try self.writeTrimmed(node);
}

pub fn writePass(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement pass keyword
    try self.writeTrimmed(node);
}

pub fn writeFunc(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement func keyword
    try self.writeTrimmed(node);
}

pub fn writeExtends(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement extends keyword
    try self.writeTrimmed(node);
}

pub fn writeConst(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement const keyword
    try self.writeTrimmed(node);
}

pub fn writeVar(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement var keyword
    try self.writeTrimmed(node);
}

pub fn writeFor(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement for keyword
    try self.writeTrimmed(node);
}

pub fn writeIn(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement in keyword
    try self.writeTrimmed(node);
}

pub fn writeIf(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement if keyword
    try self.writeTrimmed(node);
}

pub fn writeElse(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement else keyword
    try self.writeTrimmed(node);
}

pub fn writeElif(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement elif keyword
    try self.writeTrimmed(node);
}

pub fn writeReturn(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement return keyword
    try self.writeTrimmed(node);
}

pub fn writeGet(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement get keyword
    try self.writeTrimmed(node);
}

pub fn writeSet(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement set keyword
    try self.writeTrimmed(node);
}

pub fn writeMatch(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement match keyword
    try self.writeTrimmed(node);
}

pub fn writeClassName(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement class_name keyword
    try self.writeTrimmed(node);
}

pub fn writeClass(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement class keyword
    try self.writeTrimmed(node);
}

// Utility Methods
pub fn writeComment(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement comment preservation with proper spacing
    try self.writeTrimmed(node);
}

pub fn writeName(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement name nodes (may be handled by writeIdentifier)
    try self.writeTrimmed(node);
}

// Punctuation and Operators (low priority - often just pass through)
pub fn writeAt(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeOpenParen(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeCloseParen(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeOpenBracket(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeCloseBracket(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeOpenBrace(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeCloseBrace(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeComma(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeDot(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeColon(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeSemicolon(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writePlus(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writePlusEquals(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeMinus(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeMultiply(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeDivide(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeModulo(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeLessThan(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeGreaterThan(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeLessEqual(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeGreaterEqual(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeEquals(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeNotEquals(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeAssign(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeLogicalAnd(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeLogicalOr(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeLogicalNot(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeQuote(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeArrow(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeColonEquals(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

const std = @import("std");
const assert = std.debug.assert;
const Writer = std.io.Writer;

const tree_sitter = @import("tree-sitter");
const Node = tree_sitter.TSNode;

const enums = @import("enums.zig");
const NodeType = enums.GdNodeType;

const formatter = @import("formatter.zig");
const attribute = @import("attribute.zig");
const @"type" = @import("type.zig");
const Context = @import("Context.zig");
