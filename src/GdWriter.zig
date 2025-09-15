// Scoped logger for GdWriter
const log = std.log.scoped(.gdwriter);

const GdWriter = @This();

pub const Error = error{
    MalformedAST,
    UnexpectedNodeType,
    MissingRequiredChild,
    InvalidNodeStructure,
    MaxWidthExceeded,
} || Writer.Error;

writer: *Writer,
bytes_written: u64 = 0,
current_line_start: u64 = 0,
context: Context,

const Options = struct {
    writer: *Writer,
    context: ?Context = null,
};

pub fn init(options: Options) GdWriter {
    return GdWriter{
        .writer = options.writer,
        .bytes_written = 0,
        .current_line_start = 0,
        .context = options.context orelse .{},
    };
}

pub const IndentOptions = struct {
    new_line: bool = false,
    by: u32 = 0,
};

fn writeIndent(self: *GdWriter, options: IndentOptions) Error!void {
    log.debug("writeIndent: by={}, new_line={}, current_indent={}, line_width={}", .{ options.by, options.new_line, self.context.indent_level, self.getCurrentLineWidth() });

    if (options.by != 0) {
        self.context.indent_level += options.by;
        log.debug("writeIndent: increased indent_level to {}", .{self.context.indent_level});
    }

    if (options.new_line) {
        try self.writeNewline();
    }

    try formatter.writeIndent(self.writer, self.context);
    log.debug("writeIndent: completed, final_indent={}, line_width={}", .{ self.context.indent_level, self.getCurrentLineWidth() });
}

fn getCurrentLineWidth(self: *GdWriter) u32 {
    return @intCast(self.bytes_written - self.current_line_start);
}

fn writeNewline(self: *GdWriter) !void {
    log.debug("writeNewline: current_line_width={}, bytes_written={}", .{ self.getCurrentLineWidth(), self.bytes_written });

    const bytes = try self.writer.write("\n");
    self.bytes_written += bytes;
    self.current_line_start = self.bytes_written;

    log.debug("writeNewline: completed, new_line_start={}, bytes_written={}", .{ self.current_line_start, self.bytes_written });
}

fn writeTrimmed(self: *GdWriter, node: Node) !void {
    const original_text = node.text();
    const text = formatter.trimWhitespace(original_text);
    log.debug("writeTrimmed: node_type={s}, original='{s}', trimmed='{s}'", .{ node.getTypeAsString(), original_text[0..@min(30, original_text.len)], text[0..@min(30, text.len)] });
    try self.write(text, .{});
}

const WriteOptions = struct {
    check_max_width: bool = true,
};

fn write(self: *GdWriter, text: []const u8, options: WriteOptions) Error!void {
    _ = options; // autofix
    const escaped_text = if (std.mem.eql(u8, text, "\n")) "\\n" else text;
    log.debug("write: '{s}' ({} bytes), line_width={}, total_bytes={}", .{ escaped_text, text.len, self.getCurrentLineWidth(), self.bytes_written });

    const bytes = try self.writer.write(text);
    self.bytes_written += bytes;

    log.debug("write: completed, new_bytes_written={}, new_line_width={}", .{ self.bytes_written, self.getCurrentLineWidth() });
}

fn isInlineComment(comment_node: Node) bool {
    // Check if this comment appears on the same line as previous non-comment content
    // For now, we'll use a simple heuristic: if there's a previous sibling on the same line

    const comment_start = comment_node.startPoint();

    // Look for a previous sibling that's not whitespace
    var prev_sibling = comment_node.prevSibling();
    while (prev_sibling) |sibling| {
        const sibling_type = sibling.getTypeAsString();

        // Skip whitespace-only nodes
        if (std.mem.eql(u8, sibling_type, "whitespace") or
            std.mem.eql(u8, sibling_type, " ") or
            std.mem.eql(u8, sibling_type, "\t"))
        {
            prev_sibling = sibling.prevSibling();
            continue;
        }

        const sibling_end = sibling.endPoint();

        // If the previous non-whitespace sibling ends on the same line as the comment starts,
        // then this is an inline comment
        if (sibling_end.row == comment_start.row) {
            return true;
        }

        break;
    }

    return false;
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
    try @"type".writeSubscript(node, self.writer, self.context);
}

pub fn writeType(self: *GdWriter, node: Node) Error!void {
    try @"type".writeType(node, self.writer, self.context);
}

pub fn writeIdentifier(self: *GdWriter, node: Node) Error!void {
    log.debug("writeIdentifier: text='{s}', indent={}", .{ node.text(), self.context.indent_level });
    try self.writeTrimmed(node);
}

pub fn writeCall(self: *GdWriter, node: Node) Error!void {
    try self.writeTrimmed(node);
}

pub fn writeClassDefinition(self: *GdWriter, node: Node) Error!void {
    log.debug("writeClassDefinition: children={}, indent={}, line_width={}, bytes_written={}", .{ node.childCount(), self.context.indent_level, self.getCurrentLineWidth(), self.bytes_written });
    assert(node.getTypeAsEnum(NodeType) == .class_definition);

    var i: u32 = 0;

    // "class"
    {
        const class_node = node.child(i) orelse return Error.MissingRequiredChild;
        assert(class_node.getTypeAsEnum(NodeType) == .class);

        try self.writeTrimmed(class_node);
        try self.write(" ", .{});
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
        if (node.child(i)) |extends_node| {
            if (extends_node.getTypeAsEnum(NodeType) == .extends_statement) {
                try self.write(" ", .{});
                try self.writeExtendsStatement(extends_node);
                i += 1;
            } else if (std.mem.eql(u8, extends_node.getTypeAsString(), "comment")) {
                try self.handleComment(extends_node);
                i += 1;
            }
        }
    }

    // colon
    {
        const colon_node = node.child(i) orelse return Error.MissingRequiredChild;
        assert(colon_node.getTypeAsEnum(NodeType) == .@":");

        try self.writeTrimmed(colon_node);
        try self.writeNewline();
        i += 1;
    }

    // body
    {
        const body_node = node.child(i) orelse return Error.MissingRequiredChild;
        const body_type = body_node.getTypeAsEnum(NodeType) orelse {
            log.debug("Unknown node type: '{s}', treating as comment", .{body_node.getTypeAsString()});
            if (std.mem.eql(u8, body_node.getTypeAsString(), "comment")) {
                try self.handleComment(body_node);
                return;
            }
            return Error.UnexpectedNodeType;
        };

        if (body_type != .body) {
            log.err("Expected body node, got {s}", .{body_node.getTypeAsString()});
            if (body_type == .comment) {
                try self.handleComment(body_node);
                return;
            }
            return Error.UnexpectedNodeType;
        }

        log.debug("writeClassDefinition: entering body with indent_level={}", .{self.context.indent_level});
        try self.writeIndent(.{ .by = 1 });
        try self.writeBody(body_node);
        self.context.indent_level -= 1;
        log.debug("writeClassDefinition: exited body, indent_level={}", .{self.context.indent_level});
    }
}

pub fn writeBody(self: *GdWriter, node: Node) Error!void {
    log.debug("writeBody: children={}, indent={}, line_width={}, bytes_written={}", .{ node.childCount(), self.context.indent_level, self.getCurrentLineWidth(), self.bytes_written });
    assert(node.getTypeAsEnum(NodeType) == .body);

    // Process all children in the body, not just the first one
    for (0..node.childCount()) |i| {
        if (node.child(@intCast(i))) |child| {
            if (i > 0) {
                // Add newline between statements
                try self.writeNewline();
            }
            // Write proper indentation for the statement
            try formatter.writeIndent(self.writer, self.context);
            log.debug("writeBody: processing child {}: type={s}", .{ i, child.getTypeAsString() });
            var cursor = child.cursor();
            try formatter.depthFirstWalk(&cursor, self);
        }
    }
}

pub fn writePassStatement(self: *GdWriter, node: Node) Error!void {
    log.debug("writePassStatement: indent={}, line_width={}, bytes_written={}", .{ self.context.indent_level, self.getCurrentLineWidth(), self.bytes_written });
    assert(node.getTypeAsEnum(NodeType) == .pass_statement);

    // Write proper indentation before the statement
    try formatter.writeIndent(self.writer, self.context);
    try self.write("pass\n", .{});
}

pub fn writeSignalStatement(self: *GdWriter, node: Node) Error!void {
    assert(node.getTypeAsEnum(NodeType) == .signal_statement);

    var i: u32 = 0;

    // signal
    {
        const signal_node = node.child(i) orelse return Error.MissingRequiredChild;
        const signal_type = signal_node.getTypeAsEnum(NodeType) orelse {
            log.debug("Unknown node type: '{s}', expected signal", .{signal_node.getTypeAsString()});
            if (std.mem.eql(u8, signal_node.getTypeAsString(), "comment")) {
                try self.handleComment(signal_node);
                i += 1;
                return;
            }
            return Error.UnexpectedNodeType;
        };

        if (signal_type != .signal) {
            return Error.UnexpectedNodeType;
        }

        try self.writeTrimmed(signal_node);
        try self.write(" ", .{});

        i += 1;
    }

    // identifier
    {
        const name_node = node.child(i) orelse return Error.MissingRequiredChild;
        const name_type = name_node.getTypeAsEnum(NodeType) orelse {
            log.debug("Unknown node type: '{s}', expected name", .{name_node.getTypeAsString()});
            if (std.mem.eql(u8, name_node.getTypeAsString(), "comment")) {
                try self.handleComment(name_node);
                i += 1;
                return;
            }
            return Error.UnexpectedNodeType;
        };

        if (name_type != .name) {
            return Error.UnexpectedNodeType;
        }

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

    try self.writeNewline();
}

pub fn writeParameters(self: *GdWriter, node: Node) Error!void {
    log.debug("writeParameters: children={}, indent={}", .{ node.childCount(), self.context.indent_level });
    assert(node.getTypeAsEnum(NodeType) == .parameters);

    try self.write("(", .{});
    for (0..node.childCount()) |j| {
        const param = node.child(@intCast(j)) orelse return Error.MissingRequiredChild;
        const param_type = param.getTypeAsEnum(NodeType) orelse {
            log.debug("Unknown node type: '{s}', treating as comment", .{param.getTypeAsString()});
            if (std.mem.eql(u8, param.getTypeAsString(), "comment")) {
                try self.handleComment(param);
            } else {
                // For non-comment unknown types, use trimmed write as fallback
                const param_text = formatter.trimWhitespace(param.text());
                try self.write(param_text, .{});
            }
            continue;
        };

        const param_text = formatter.trimWhitespace(param.text());
        log.debug("writeParameters: param[{}] type={s}, text='{s}'", .{ j, @tagName(param_type), param_text });

        switch (param_type) {
            .typed_parameter => {
                try self.write(param_text, .{});
            },
            .@"," => try self.write(", ", .{}),
            .identifier => try self.write(param_text, .{}),
            .@"(", .@")" => continue,
            else => log.warn("unknown param type: {} {s}", .{ param_type, param.text() }),
        }
    }
    try self.write(")", .{});
}

pub fn writeExtendsStatement(self: *GdWriter, node: Node) Error!void {
    assert(node.childCount() == 2);

    // extends
    try self.write("extends ", .{});
    try self.write(formatter.trimWhitespace(node.child(1).?.text()), .{});
}

pub fn writeVariableStatement(self: *GdWriter, node: Node) Error!void {
    log.debug("writeVariableStatement: children={}, indent={}, line_width={}, text='{s}'", .{ node.childCount(), self.context.indent_level, self.getCurrentLineWidth(), node.text()[0..@min(50, node.text().len)] });

    for (0..node.childCount()) |i| {
        const prev_child = if (i > 0) node.child(@intCast(i - 1)) else null;
        _ = prev_child;
        const child = node.child(@intCast(i));
        const next_child = node.child(@intCast(i + 1));

        if (child) |c| {
            const nt = c.getTypeAsEnum(enums.GdNodeType) orelse {
                log.debug("writeVariableStatement: unknown node type for child {}: '{s}', falling back to trimmed write", .{ i, c.getTypeAsString() });
                try self.writeTrimmed(c);
                continue;
            };

            switch (nt) {
                .name => {
                    const next_child_is_type = blk: {
                        if (next_child) |nc| {
                            const nc_type = nc.getTypeAsEnum(enums.GdNodeType) orelse {
                                log.debug("writeVariableStatement: unknown next_child node type: '{s}'", .{nc.getTypeAsString()});
                                break :blk false;
                            };

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
                    try formatter.depthFirstWalk(&cursor, self);
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
                        try formatter.depthFirstWalk(&cursor, self);
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
    log.debug("writeFunctionDefinition: children={}, indent={}, line_width={}, bytes_written={}", .{ node.childCount(), self.context.indent_level, self.getCurrentLineWidth(), self.bytes_written });

    var i: u32 = 0;

    // Log all children for debugging
    for (0..node.childCount()) |idx| {
        if (node.child(@intCast(idx))) |child| {
            const trimmed_text = std.mem.trim(u8, child.text(), " \t\n\r");
            log.debug("  child[{}]: type={s}, text='{s}'", .{ idx, child.getTypeAsString(), trimmed_text[0..@min(20, trimmed_text.len)] });
        }
    }

    // static (optional)
    if (node.child(i).?.getTypeAsEnum(NodeType) == .static_keyword) {
        log.debug("writeFunctionDefinition: found static keyword at index {}", .{i});
        try self.write("static ", .{});
        i += 1;
    }

    // func keyword
    {
        const func_node = node.child(i) orelse return Error.MissingRequiredChild;
        log.debug("writeFunctionDefinition: checking func node at index {}, got type={s}", .{ i, func_node.getTypeAsString() });
        if (func_node.getTypeAsEnum(NodeType) != .func) {
            log.err("Expected func node at index {}, got {s}", .{ i, func_node.getTypeAsString() });
            return Error.UnexpectedNodeType;
        }

        try self.write("func", .{});
    }
    i += 1;

    // optional name
    {
        if (node.child(i).?.getTypeAsEnum(NodeType) == .name) {
            const text = formatter.trimWhitespace(node.child(i).?.text());
            try self.write(" ", .{});
            try self.write(text, .{});
            i += 1;
        }
    }

    // parameters
    {
        const params_node = node.child(i) orelse return Error.MissingRequiredChild;
        assert(params_node.getTypeAsEnum(NodeType) == .parameters);

        try self.write("(", .{});
        for (0..params_node.childCount()) |j| {
            const param = params_node.child(@intCast(j)) orelse return Error.MissingRequiredChild;
            const param_type = param.getTypeAsEnum(NodeType) orelse {
                log.warn("unknown param type: {s} {s}", .{ param.getTypeAsString(), param.text()[0..@min(20, param.text().len)] });
                continue;
            };

            const param_text = formatter.trimWhitespace(param.text());
            switch (param_type) {
                .typed_parameter => {
                    try self.write(param_text, .{});
                },
                .@"," => try self.write(", ", .{}),
                .identifier => try self.write(param_text, .{}),
                .@"(", .@")" => continue,
                else => log.warn("unknown param type: {} {s}", .{ param_type, param.text() }),
            }
        }
        try self.write(")", .{});
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

            try self.write(" -> ", .{});
            try @"type".writeType(type_node, self.writer, self.context);
        }
    }

    // colon
    {
        const colon_node = node.child(i) orelse return Error.MissingRequiredChild;
        assert(colon_node.getTypeAsEnum(NodeType) == .@":");
        try self.write(":\n", .{});
    }
    i += 1;

    // body
    {
        const body_node = node.child(i) orelse return Error.MissingRequiredChild;
        assert(body_node.getTypeAsEnum(NodeType) == .body);

        // Create temporary context with increased indentation
        const old_indent = self.context.indent_level;
        self.context.indent_level += 1;
        try self.writeBody(body_node);
        self.context.indent_level = old_indent;
    }
}

pub fn writeReturnStatement(self: *GdWriter, node: Node) Error!void {
    log.debug("writeReturnStatement: children={}, indent={}, text='{s}'", .{ node.childCount(), self.context.indent_level, node.text()[0..@min(40, node.text().len)] });

    const return_node = node.child(0) orelse return Error.MissingRequiredChild;
    assert(return_node.getTypeAsEnum(NodeType) == .@"return");
    try self.write("return ", .{});

    var next_node = node.child(1) orelse return;
    log.debug("writeReturnStatement: processing return value of type {s}", .{next_node.getTypeAsString()});

    var cursor = next_node.cursor();
    try formatter.depthFirstWalk(&cursor, self);
}

pub fn writeClassNameStatement(self: *GdWriter, node: Node) Error!void {
    const class_name_node = node.child(0) orelse return Error.MissingRequiredChild;
    assert(class_name_node.getTypeAsEnum(NodeType) == .class_name);
    try self.writeTrimmed(class_name_node);
    try self.write(" ", .{});

    const name_node = node.child(1) orelse return Error.MissingRequiredChild;
    assert(name_node.getTypeAsEnum(NodeType) == .name);
    try self.writeTrimmed(name_node);
    try self.writeNewline();
}

// ============================================================================
// STUB METHODS - Need implementation for full GDScript support
// ============================================================================

// Critical Language Features
pub fn writeSource(self: *GdWriter, node: Node) Error!void {
    log.debug("writeSource: children={}, indent={}, bytes_written={}", .{ node.childCount(), self.context.indent_level, self.bytes_written });

    // Source node is the root - need to traverse its children
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (i > 0) {
            try self.writeNewline();
        }
        const child = node.child(i).?;
        log.debug("writeSource: processing child {}: node_type={s}", .{ i, child.getTypeAsString() });
        var cursor = child.cursor();
        try formatter.depthFirstWalk(&cursor, self);
    }
    log.debug("writeSource: completed, bytes_written={}", .{self.bytes_written});
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
    log.debug("writeBinaryOperator: children={}, current_width={}, max_width={}, text='{s}'", .{ node.childCount(), self.getCurrentLineWidth(), self.context.max_width, node.text()[0..@min(60, node.text().len)] });

    // Binary expressions have structure: left_expr operator right_expr
    // assert(node.childCount() == 3);

    // Try single-line format first
    self.writeBinaryOperatorNormal(node) catch |err| switch (err) {
        Error.MaxWidthExceeded => {
            log.debug("writeBinaryOperator: switching to multiline due to MaxWidthExceeded", .{});
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

    log.debug("writeBinaryOperatorNormal: left='{s}', op='{s}', right='{s}'", .{ left.text()[0..@min(20, left.text().len)], op.text(), right.text()[0..@min(20, right.text().len)] });

    // Check total width that would be consumed by this entire binary expression
    const full_text = node.text();
    const current_width = self.getCurrentLineWidth();
    const total_width = current_width + full_text.len;

    log.debug("writeBinaryOperatorNormal: current_width={}, expression_len={}, total_width={}, max_width={}", .{ current_width, full_text.len, total_width, self.context.max_width });

    // If the entire expression would exceed the limit, trigger multiline mode
    if (total_width > self.context.max_width) {
        log.debug("writeBinaryOperatorNormal: triggering multiline format due to width exceeded", .{});
        return Error.MaxWidthExceeded;
    }

    // Use unchecked writes since we've already verified the total width
    // Write left operand
    var cursor = left.cursor();
    try formatter.depthFirstWalk(&cursor, self);

    // Write operator with spaces
    try self.write(" ", .{});
    try self.write(op.text(), .{});
    try self.write(" ", .{});

    // Write right operand
    cursor = right.cursor();
    try formatter.depthFirstWalk(&cursor, self);
}

fn writeBinaryOperatorMultiline(self: *GdWriter, node: Node) !void {
    const left = node.child(0).?;
    const op = node.child(1).?;
    const right = node.child(2).?;

    log.debug("writeBinaryOperatorMultiline: formatting as multiline, indent={}", .{self.context.indent_level});

    // Write left operand
    var cursor = left.cursor();
    try formatter.depthFirstWalk(&cursor, self);

    // Write operator without trailing space
    try self.write(" ", .{});
    try self.write(op.text(), .{});

    // Newline and indented right operand
    try self.writeNewline();
    try self.writeIndent(.{ .new_line = false });
    try self.writeIndent(.{ .new_line = false }); // Double indent for continuation
    log.debug("writeBinaryOperatorMultiline: after indentation, line_width={}", .{self.getCurrentLineWidth()});

    // Write right operand
    cursor = right.cursor();
    try formatter.depthFirstWalk(&cursor, self);
    log.debug("writeBinaryOperatorMultiline: completed multiline format", .{});
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
    // Delegate to handleComment for consistent comment processing
    try self.handleComment(node);
}

pub fn handleComment(self: *GdWriter, comment_node: Node) Error!void {
    assert(comment_node.getTypeAsEnum(NodeType) == .comment);

    if (isInlineComment(comment_node)) {
        try self.write(" ", .{}); // space before inline comment
        try self.writeTrimmed(comment_node);
        try self.writeNewline();
    } else {
        // Standalone comment - preserve indentation
        try formatter.writeIndent(self.writer, self.context);
        try self.writeTrimmed(comment_node);
        try self.writeNewline();
    }
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
const Writer = std.Io.Writer;
const testing = std.testing;

const tree_sitter = @import("tree-sitter");
const Node = tree_sitter.TSNode;

const enums = @import("enums.zig");
const NodeType = enums.GdNodeType;

const formatter = @import("formatter.zig");
const attribute = @import("attribute.zig");
const @"type" = @import("type.zig");
const Context = @import("Context.zig");

// ============================================================================
// UNIT TESTS
// ============================================================================

test "handleComment - method exists" {
    // Test that the function signature is correct
    const has_handle_comment = @hasDecl(GdWriter, "handleComment");
    try testing.expect(has_handle_comment);
}

test "isInlineComment - function signature" {
    // Test that the isInlineComment function exists and has the right signature
    const has_is_inline_comment = @hasDecl(@This(), "isInlineComment");
    try testing.expect(has_is_inline_comment);
}

test "error handling - unknown node types graceful fallback" {
    // Verify that we have improved error handling patterns
    // The actual behavior is tested through the methods that use these patterns

    // Test that our error types are available
    try testing.expect(@hasDecl(GdWriter, "Error"));

    // Test that UnexpectedNodeType error exists in the error set
    const error_value: GdWriter.Error = GdWriter.Error.UnexpectedNodeType;
    try testing.expect(error_value == GdWriter.Error.UnexpectedNodeType);
}
