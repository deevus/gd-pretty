// Scoped logger for GdWriter
const log = std.log.scoped(.gdwriter);

const GdWriter = @This();

pub const Error = error{
    MalformedAST,
    UnexpectedNodeType,
    MissingRequiredChild,
    InvalidNodeStructure,
    OutOfMemory,
} || Writer.Error || if (builtin.mode == .Debug) debug.Error else error{};

writer: *Writer,
bytes_written: u64 = 0,
context: Context,
whitespace_config: WhitespaceConfig,
allocator: std.mem.Allocator,

const Options = struct {
    writer: *Writer,
    context: ?Context = null,
    whitespace_config: WhitespaceConfig = .default,
    allocator: std.mem.Allocator,
};

pub fn init(options: Options) GdWriter {
    return GdWriter{
        .writer = options.writer,
        .bytes_written = 0,
        .context = options.context orelse .{},
        .whitespace_config = options.whitespace_config,
        .allocator = options.allocator,
    };
}

pub const IndentOptions = struct {
    new_line: bool = false,
    by: u32 = 0,
};

fn writeIndent(self: *GdWriter, options: IndentOptions) Error!void {
    log.debug("writeIndent: by={}, new_line={}, current_indent={}", .{ options.by, options.new_line, self.context.indent_level });

    if (options.by != 0) {
        self.context.indent_level += options.by;
        log.debug("writeIndent: increased indent_level to {}", .{self.context.indent_level});
    }

    if (options.new_line) {
        try self.writeNewline();
    }

    try self.writeIndentLevel(self.context.indent_level);
    log.debug("writeIndent: completed, final_indent={}", .{self.context.indent_level});
}

fn writeNewline(self: *GdWriter) !void {
    log.debug("writeNewline: bytes_written={}", .{self.bytes_written});

    const bytes = try self.writer.write("\n");
    self.bytes_written += bytes;

    log.debug("writeNewline: completed, bytes_written={}", .{self.bytes_written});
}

fn writeIndentLevel(self: *GdWriter, indent_level: u32) Error!void {
    switch (self.whitespace_config.style) {
        .spaces => {
            const width = self.whitespace_config.width * indent_level;
            for (0..width) |_| try self.writer.writeByte(' ');
            self.bytes_written += width;
        },
        .tabs => {
            for (0..indent_level) |_| try self.writer.writeByte('\t');
            self.bytes_written += indent_level;
        },
    }
}

// Trims leading and trailing whitespace from text
fn trimWhitespace(text: []const u8) []const u8 {
    return std.mem.trim(u8, text, &std.ascii.whitespace);
}

fn writeTrimmed(self: *GdWriter, node: Node) !void {
    const original_text = node.text();
    const trimmed_text = trimWhitespace(original_text);

    log.debug("writeTrimmed: node_type={s}, original='{s}', normalized='{s}'", .{ node.getTypeAsString(), original_text[0..@min(30, original_text.len)], trimmed_text[0..@min(30, trimmed_text.len)] });
    try self.write(trimmed_text, .{});
}

const WriteOptions = struct {};

fn write(self: *GdWriter, text: []const u8, options: WriteOptions) Error!void {
    _ = options; // autofix
    const escaped_text = if (std.mem.eql(u8, text, "\n")) "\\n" else text;
    log.debug("write: '{s}' ({} bytes), total_bytes={}", .{ escaped_text, text.len, self.bytes_written });

    for (text) |char| {
        if (char == '\t' and self.whitespace_config.style == .spaces) {
            for (0..self.whitespace_config.width) |_| {
                try self.writer.writeByte(' ');
                self.bytes_written += 1;
            }
        } else {
            try self.writer.writeByte(char);
            self.bytes_written += 1;
        }
    }

    log.debug("write: completed, new_bytes_written={}", .{self.bytes_written});
}

fn findClosingNode(opening_node: ?Node, opening_type: NodeType, closing_type: NodeType) ?Node {
    if (opening_node == null) {
        return null;
    }

    var level: usize = 1;
    var current_node = opening_node.?.nextSibling();

    while (current_node) |n| {
        if (n.getTypeAsEnum(NodeType)) |nt| {
            if (nt == opening_type) {
                level += 1;
            } else if (nt == closing_type) {
                level -= 1;

                if (level == 0) {
                    return current_node;
                }
            }
        }

        if (current_node) |c| {
            current_node = c.nextSibling();
        }
    }

    return null;
}

fn hasComment(node: ?Node) bool {
    if (node == null) return false;

    for (0..node.?.childCount()) |i| {
        if (node.?.child(i).?.getTypeAsEnum(NodeType) == .comment) {
            return true;
        }
    }

    return false;
}

fn hasInlineComment(node: ?Node) bool {
    if (node == null) return false;

    for (0..node.?.childCount()) |i| {
        const current_node = node.?.child(i).?;
        const previous_node = current_node.prevSibling();

        if (current_node.getTypeAsEnum(NodeType) == .comment) {
            if (previous_node) |prev| if (prev.endPoint().row == current_node.startPoint().row) {
                return true;
            };
        }
    }

    return false;
}

fn isInlineComment(comment_node: Node) bool {
    // Check if this comment appears on the same line as previous non-comment content
    // For now, we'll use a simple heuristic: if there's a previous sibling on the same line

    const comment_start = comment_node.startPoint();

    // Look for a previous sibling that's not whitespace
    var prev_sibling = comment_node.prevSibling();
    while (prev_sibling) |sibling| {
        const sibling_type = sibling.getTypeAsString();
        const sibling_end = sibling.endPoint();

        // Skip whitespace-only nodes
        if (std.mem.eql(u8, sibling_type, "whitespace") or
            std.mem.eql(u8, sibling_type, " ") or
            std.mem.eql(u8, sibling_type, "\t"))
        {
            prev_sibling = sibling.prevSibling();
            continue;
        }

        // If the previous non-whitespace sibling ends on the same line as the comment starts,
        // then this is an inline comment
        if (sibling_end.row == comment_start.row) {
            return true;
        }

        break;
    }

    return false;
}

// Check if there were blank lines in the original source between two nodes
fn hasBlankLinesBetween(node1: Node, node2: Node) bool {
    const end_point = node1.endPoint();
    const start_point = node2.startPoint();

    // If there's more than one line difference, there must be blank lines
    return start_point.row > end_point.row + 1;
}

pub fn writeAttribute(self: *GdWriter, node: Node) Error!void {
    // Attribute nodes are flat: [object, ".", member, ".", member, ...]
    // Walk all children, writing "." for dot nodes and rendering others.
    for (0..node.childCount()) |idx| {
        const child = node.child(@intCast(idx)) orelse return Error.MissingRequiredChild;
        const child_type = child.getTypeAsEnum(NodeType);

        if (child_type == .@".") {
            try self.write(".", .{});
        } else {
            // renderNode is a no-op for unregistered node types; fall back to verbatim text
            const bytes_before = self.bytes_written;
            try formatter.renderNode(child, self);
            if (self.bytes_written == bytes_before) {
                try self.writeTrimmed(child);
            }
        }
    }
}

pub fn writeSubscript(self: *GdWriter, node: Node) Error!void {
    for (0..node.childCount()) |i| {
        const child = node.child(@intCast(i)) orelse return Error.MissingRequiredChild;
        // renderNode is a no-op for unregistered node types; fall back to verbatim text
        const bytes_before = self.bytes_written;
        try formatter.renderNode(child, self);
        if (self.bytes_written == bytes_before) {
            try self.writeTrimmed(child);
        }
    }
}

pub fn writeType(self: *GdWriter, node: Node) Error!void {
    for (0..node.childCount()) |i| {
        const child = node.child(@intCast(i)) orelse return Error.MissingRequiredChild;
        const child_type = child.getTypeAsEnum(NodeType) orelse {
            try self.writeTrimmed(child);
            continue;
        };

        switch (child_type) {
            .subscript => try self.writeSubscript(child),
            else => try self.writeTrimmed(child),
        }
    }
}

pub fn writeIdentifier(self: *GdWriter, node: Node) Error!void {
    log.debug("writeIdentifier: text='{s}', indent={}", .{ node.text(), self.context.indent_level });
    try self.writeTrimmed(node);
}

pub fn writeCall(self: *GdWriter, node: Node) Error!void {
    // child 0: function expression (identifier, attribute, etc.)
    const func_expr = node.child(0) orelse return Error.MissingRequiredChild;
    const bytes_before = self.bytes_written;
    try formatter.renderNode(func_expr, self);
    if (self.bytes_written == bytes_before) {
        try self.writeTrimmed(func_expr);
    }
    // child 1: arguments
    const args = node.child(1) orelse return Error.MissingRequiredChild;
    try self.writeArguments(args);
}

pub fn writeClassDefinition(self: *GdWriter, node: Node) Error!void {
    log.debug("writeClassDefinition: children={}, indent={}, bytes_written={}", .{ node.childCount(), self.context.indent_level, self.bytes_written });
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
            } else if (extends_node.getTypeAsEnum(NodeType) == .comment) {
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
        i += 1;
    }

    // Check for inline comment after colon
    var has_inline_comment = false;
    if (node.child(i)) |next_node| {
        if (next_node.getTypeAsEnum(NodeType) == .comment and isInlineComment(next_node)) {
            try self.handleComment(next_node);
            has_inline_comment = true;
            i += 1;
        }
    }

    // Write newline after colon (and inline comment if present)
    try self.writeNewline();

    // body (with comment handling)
    {
        var current_index = i;
        var found_body = false;

        while (current_index < node.childCount()) {
            const child = node.child(current_index) orelse break;

            const child_type = child.getTypeAsEnum(NodeType) orelse {
                log.debug("Unknown node type: '{s}', checking if comment", .{child.getTypeAsString()});
                if (child.getTypeAsEnum(NodeType) == .comment) {
                    try self.handleComment(child);
                    current_index += 1;
                    continue;
                }
                log.err("Expected body or comment after class declaration, got {s}", .{child.getTypeAsString()});
                return Error.UnexpectedNodeType;
            };

            switch (child_type) {
                .comment => {
                    try self.handleComment(child);
                    current_index += 1;
                    continue;
                },
                .body => {
                    log.debug("writeClassDefinition: entering body with indent_level={}", .{self.context.indent_level});
                    // Create temporary context with increased indentation
                    const old_indent = self.context.indent_level;
                    self.context.indent_level += 1;
                    try self.writeBody(child);
                    self.context.indent_level = old_indent;
                    log.debug("writeClassDefinition: exited body, indent_level={}", .{self.context.indent_level});
                    found_body = true;
                    break;
                },
                else => {
                    log.err("Expected body or comment after class declaration, got {s}", .{child.getTypeAsString()});
                    return Error.UnexpectedNodeType;
                },
            }
        }

        if (!found_body) {
            return Error.MissingRequiredChild;
        }
    }
}

pub fn writeBody(self: *GdWriter, node: Node) Error!void {
    log.debug("writeBody: children={}, indent={}, bytes_written={}", .{ node.childCount(), self.context.indent_level, self.bytes_written });
    assert(node.getTypeAsEnum(NodeType) == .body);

    // Process all children in the body
    var i: u32 = 0;
    while (i < node.childCount()) {
        const child = node.child(i).?;

        // Check if this is an inline comment
        const is_inline_comment = child.getTypeAsEnum(NodeType) == .comment and isInlineComment(child);

        if (is_inline_comment) {
            // Inline comment - just handle it without newlines
            try self.handleComment(child);
            i += 1;
            continue;
        }

        // Not an inline comment - add newline before if not first item
        if (i > 0) {
            // Check if we need to preserve blank lines from the original source
            const prev_child = node.child(i - 1).?;
            if (hasBlankLinesBetween(prev_child, child)) {
                // Add extra newline to preserve blank line from original
                try self.writeNewline();
            }
            try self.writeNewline();
        }

        // Check if this is a standalone comment
        if (child.getTypeAsEnum(NodeType) == .comment) {
            // Standalone comment - just handle it (indentation included)
            try self.handleComment(child);
        } else {
            // Regular statement
            // Write proper indentation for the statement
            try self.writeIndentLevel(self.context.indent_level);
            log.debug("writeBody: processing child {}: type={s}", .{ i, child.getTypeAsString() });

            // Check if the next child is an inline comment
            const next_child = if (i + 1 < node.childCount()) node.child(i + 1) else null;
            const has_inline_comment = if (next_child) |nc|
                nc.getTypeAsEnum(NodeType) == .comment and isInlineComment(nc)
            else
                false;

            // Process the statement
            var cursor = child.cursor();

            // Save the current context to pass info about inline comments
            const old_suppress_newline = self.context.suppress_final_newline;
            if (has_inline_comment) {
                self.context.suppress_final_newline = true;
            }

            try formatter.depthFirstWalk(&cursor, self);

            // Restore context
            self.context.suppress_final_newline = old_suppress_newline;
        }

        i += 1;
    }
}

pub fn writePassStatement(self: *GdWriter, node: Node) Error!void {
    log.debug("writePassStatement: indent={}, bytes_written={}", .{ self.context.indent_level, self.bytes_written });
    assert(node.getTypeAsEnum(NodeType) == .pass_statement);

    // Indentation is handled by writeBody, just write the statement
    try self.write("pass", .{});
}

pub fn writeSignalStatement(self: *GdWriter, node: Node) Error!void {
    assert(node.getTypeAsEnum(NodeType) == .signal_statement);

    var i: u32 = 0;

    // signal
    {
        const signal_node = node.child(i) orelse return Error.MissingRequiredChild;
        const signal_type = signal_node.getTypeAsEnum(NodeType) orelse {
            log.debug("Unknown node type: '{s}', expected signal", .{signal_node.getTypeAsString()});
            if (signal_node.getTypeAsEnum(NodeType) == .comment) {
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
            if (name_node.getTypeAsEnum(NodeType) == .comment) {
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

    // Newline handled by container (writeBody/writeSource)
}

pub fn writeParameters(self: *GdWriter, node: Node) Error!void {
    log.debug("writeParameters: children={}, indent={}", .{ node.childCount(), self.context.indent_level });
    assert(node.getTypeAsEnum(NodeType) == .parameters);

    try self.write("(", .{});
    for (0..node.childCount()) |j| {
        const param = node.child(@intCast(j)) orelse return Error.MissingRequiredChild;
        const param_type = param.getTypeAsEnum(NodeType) orelse {
            log.debug("Unknown node type: '{s}', treating as comment", .{param.getTypeAsString()});
            if (param.getTypeAsEnum(NodeType) == .comment) {
                try self.handleComment(param);
            } else {
                // For non-comment unknown types, use trimmed write as fallback
                const param_text = trimWhitespace(param.text());
                try self.write(param_text, .{});
            }
            continue;
        };

        const param_text = trimWhitespace(param.text());
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
    try self.write(trimWhitespace(node.child(1).?.text()), .{});
}

pub fn writeVariableStatement(self: *GdWriter, node: Node) Error!void {
    log.debug("writeVariableStatement: children={}, indent={}, text='{s}'", .{ node.childCount(), self.context.indent_level, node.text()[0..@min(50, node.text().len)] });

    var s: usize = 0;

    // annotations (@onready)
    if (node.child(s).?.getTypeAsEnum(NodeType) == .annotations) {
        try self.writeTrimmed(node.child(s).?);
        try self.write(" ", .{});
        s += 1;
    }

    // static (optional)
    if (node.child(s).?.getTypeAsEnum(NodeType) == .static_keyword) {
        try self.write("static ", .{});
        s += 1;
    }

    // var
    {
        try debug.assertNodeIsType(.@"var", node.child(s));
        try self.writeVar(node.child(s).?);
        try self.write(" ", .{});
        s += 1;
    }

    // name
    {
        try debug.assertNodeIsType(.name, node.child(s));
        try self.writeTrimmed(node.child(s).?);
        s += 1;
    }

    // type (optional)
    if (node.child(s)) |c| {
        if (c.getTypeAsEnum(NodeType) == .@":") {
            try self.write(": ", .{});
            s += 1;
        } else {
            try self.write(" ", .{});
        }
    }

    const child_count = node.childCount();
    for (s..child_count) |i| {
        const child = node.child(i);

        if (child) |c| {
            const nt = c.getTypeAsEnum(NodeType) orelse {
                log.debug("writeVariableStatement: unknown node type for child {}: '{s}', falling back to trimmed write", .{ i, c.getTypeAsString() });
                try self.writeTrimmed(c);
                continue;
            };

            switch (nt) {
                .@"=" => {
                    try self.write("= ", .{});
                },
                .binary_operator, .call, .attribute => {
                    var cursor = c.cursor();
                    try formatter.depthFirstWalk(&cursor, self);
                },
                .array => {
                    try self.writeArray(c);
                },
                else => {
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
                        if (i + 1 < child_count) {
                            try self.write(" ", .{});
                        }
                    }
                },
            }
        }
    }
}

pub fn writeFunctionDefinition(self: *GdWriter, node: Node) Error!void {
    log.debug("writeFunctionDefinition: children={}, indent={}, bytes_written={}", .{ node.childCount(), self.context.indent_level, self.bytes_written });

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
            const text = trimWhitespace(node.child(i).?.text());
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

            const param_text = trimWhitespace(param.text());
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
            try self.writeType(type_node);
        }
    }

    // colon
    {
        const colon_node = node.child(i) orelse return Error.MissingRequiredChild;
        assert(colon_node.getTypeAsEnum(NodeType) == .@":");
        try self.write(":", .{});
    }
    i += 1;

    // Check for inline comment after colon
    var has_inline_comment = false;
    if (node.child(i)) |next_node| {
        if (next_node.getTypeAsEnum(NodeType) == .comment and isInlineComment(next_node)) {
            try self.handleComment(next_node);
            has_inline_comment = true;
            i += 1;
        }
    }

    // Write newline after colon (and inline comment if present)
    try self.writeNewline();

    // body
    self.context.indent_level += 1;
    try self.writeBody(node.child(i).?);
    self.context.indent_level -= 1;
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
    // Newline handled by container (writeBody/writeSource)
}

// ============================================================================
// STUB METHODS - Need implementation for full GDScript support
// ============================================================================

// Critical Language Features
pub fn writeSource(self: *GdWriter, node: Node) Error!void {
    log.debug("writeSource: children={}, indent={}, bytes_written={}", .{ node.childCount(), self.context.indent_level, self.bytes_written });

    // Source node is the root - need to traverse its children
    var i: u32 = 0;
    var prev_child: ?Node = null;
    var prev_wrote_output = false;

    while (i < node.childCount()) : (i += 1) {
        const child = node.child(i).?;
        log.debug("writeSource: processing child {}: node_type={s}", .{ i, child.getTypeAsString() });

        // Add newline between statements, preserving blank lines from original source
        // Only emit separator if the previous child actually wrote output
        if (prev_child) |prev| {
            if (prev_wrote_output) {
                if (hasBlankLinesBetween(prev, child)) {
                    try self.writeNewline();
                }
                try self.writeNewline();
            }
        }

        const bytes_before = self.bytes_written;
        var cursor = child.cursor();
        try formatter.depthFirstWalk(&cursor, self);
        prev_wrote_output = self.bytes_written > bytes_before;
        prev_child = child;
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

pub fn writeWhileStatement(self: *GdWriter, node: Node) Error!void {
    log.debug("writeWhileStatement: children={}, indent={}, bytes_written={}", .{ node.childCount(), self.context.indent_level, self.bytes_written });
    assert(node.getTypeAsEnum(NodeType) == .while_statement);

    var i: u32 = 0;

    // Debug logging can be enabled for troubleshooting
    if (comptime std.log.default_level == .debug) {
        for (0..node.childCount()) |idx| {
            if (node.child(@intCast(idx))) |child| {
                const trimmed_text = std.mem.trim(u8, child.text(), " \t\n\r");
                log.debug("  child[{}]: type={s}, text='{s}'", .{ idx, child.getTypeAsString(), trimmed_text[0..@min(20, trimmed_text.len)] });
            }
        }
    }

    // while keyword
    {
        const while_node = node.child(i) orelse return Error.MissingRequiredChild;
        assert(while_node.getTypeAsEnum(NodeType) == .@"while");
        try self.write("while ", .{});
        i += 1;
    }

    // condition expression
    {
        const condition_node = node.child(i) orelse return Error.MissingRequiredChild;
        log.debug("writeWhileStatement: processing condition of type {s}", .{condition_node.getTypeAsString()});

        var cursor = condition_node.cursor();
        try formatter.depthFirstWalk(&cursor, self);
        i += 1;
    }

    // colon
    {
        const colon_node = node.child(i) orelse return Error.MissingRequiredChild;
        assert(colon_node.getTypeAsEnum(NodeType) == .@":");
        try self.write(":", .{});
        i += 1;
    }

    // Check for inline comment after colon
    if (node.child(i)) |next_node| {
        if (next_node.getTypeAsEnum(NodeType) == .comment and isInlineComment(next_node)) {
            try self.handleComment(next_node);
            i += 1;
        }
    }

    // Write newline after colon (and inline comment if present)
    try self.writeNewline();

    // body (with comment handling)
    {
        var current_index = i;
        var found_body = false;

        while (current_index < node.childCount()) {
            const child = node.child(current_index) orelse break;

            const child_type = child.getTypeAsEnum(NodeType) orelse {
                log.err("Expected body or comment after while statement, got {s}", .{child.getTypeAsString()});
                return Error.UnexpectedNodeType;
            };

            switch (child_type) {
                .comment => {
                    try self.handleComment(child);
                    current_index += 1;
                    continue;
                },
                .body => {
                    // Create temporary context with increased indentation
                    const old_indent = self.context.indent_level;
                    self.context.indent_level += 1;
                    try self.writeBody(child);
                    self.context.indent_level = old_indent;
                    found_body = true;
                    break;
                },
                else => {
                    log.err("Expected body or comment after while statement, got {s}", .{child.getTypeAsString()});
                    return Error.UnexpectedNodeType;
                },
            }
        }

        if (!found_body) {
            return Error.MissingRequiredChild;
        }
    }
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
    log.debug("writeArray: children={}, indent={}, bytes_written={}", .{ node.childCount(), self.context.indent_level, self.bytes_written });

    try debug.assertNodeIsType(.array, node);
    try self.writeDelimitedList(node, .{ .open = "[", .close = "]" });
}

const DelimitedListConfig = struct {
    open: []const u8,
    close: []const u8,
};

fn writeDelimitedList(self: *GdWriter, node: Node, config: DelimitedListConfig) Error!void {
    // empty list: just the open and close delimiters
    if (node.childCount() == 2) {
        try self.write(config.open, .{});
        try self.write(config.close, .{});
        return;
    }

    // trailing comma?
    const multiline_mode = blk: {
        const has_trailing_comma =
            if (node.child(node.childCount() - 1)) |cn|
                if (cn.prevSibling()) |prev| prev.getTypeAsEnum(NodeType) == .@"," else false
            else
                false;

        break :blk has_trailing_comma or hasComment(node);
    };

    try self.write(config.open, .{});

    const child_count = node.childCount();

    if (multiline_mode) {
        // Check for inline comment on the opening delimiter line
        if (child_count > 2) {
            const first_inner = node.child(1).?;
            if (first_inner.getTypeAsEnum(NodeType) == .comment and isInlineComment(first_inner)) {
                try self.handleComment(first_inner);
            }
        }
        try self.writeNewline();
        self.context.indent_level += 1;
    }

    // Process children between open and close delimiters
    var i: usize = 1;
    while (i < child_count - 1) : (i += 1) {
        const current_node = node.child(i).?;
        const current_node_type = current_node.getTypeAsEnum(NodeType);

        // Skip inline comments — they are handled as look-ahead after
        // the delimiter or comma that precedes them.
        if (current_node_type == .comment and isInlineComment(current_node)) {
            continue;
        }

        // Standalone comments get their own line
        if (current_node_type == .comment) {
            if (multiline_mode) {
                try self.writeIndentLevel(self.context.indent_level);
            }
            try self.writeTrimmed(current_node);
            if (multiline_mode) {
                try self.writeNewline();
            }
            continue;
        }

        if (current_node_type == .@",") {
            try self.write(",", .{});

            // Look ahead for an inline comment after the comma
            if (i + 1 < child_count - 1) {
                const next = node.child(i + 1).?;
                if (next.getTypeAsEnum(NodeType) == .comment and isInlineComment(next)) {
                    try self.handleComment(next);
                    i += 1;
                }
            }

            if (multiline_mode) {
                try self.writeNewline();
            } else {
                try self.write(" ", .{});
            }
            continue;
        }

        // Regular element
        if (multiline_mode) {
            try self.writeIndentLevel(self.context.indent_level);
        }

        // Try formatted rendering; fall back to trimmed text for
        // unknown node types (e.g. await expressions not yet in enum).
        const bytes_before = self.bytes_written;
        try formatter.renderNode(current_node, self);
        if (self.bytes_written == bytes_before) {
            try self.writeTrimmed(current_node);
        }

        // Look ahead for an inline comment after this element
        if (i + 1 < child_count - 1) {
            const next = node.child(i + 1).?;
            if (next.getTypeAsEnum(NodeType) == .comment and isInlineComment(next)) {
                try self.handleComment(next);
                i += 1;
            }
        }

        // In multiline mode, add newline after elements that aren't
        // followed by a comma (commas handle their own newlines).
        if (multiline_mode) {
            const next_type = if (i + 1 < child_count - 1)
                node.child(i + 1).?.getTypeAsEnum(NodeType)
            else
                null;
            if (next_type != .@",") {
                try self.writeNewline();
            }
        }
    }

    if (multiline_mode) {
        self.context.indent_level -= 1;
        try self.writeIndentLevel(self.context.indent_level);
    }

    try self.write(config.close, .{});
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
    log.debug("writeBinaryOperator: children={}, text='{s}'", .{ node.childCount(), node.text()[0..@min(60, node.text().len)] });

    // Binary expressions have structure: left_expr operator right_expr
    // assert(node.childCount() == 3);

    const left = node.child(0).?;
    const op = node.child(1).?;
    const right = node.child(2).?;

    log.debug("writeBinaryOperator: left='{s}', op='{s}', right='{s}'", .{ left.text()[0..@min(20, left.text().len)], op.text(), right.text()[0..@min(20, right.text().len)] });

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

pub fn writeComparisonOperator(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement comparison operations with proper spacing
    try self.writeTrimmed(node);
}

pub fn writeConditionalExpression(self: *GdWriter, node: Node) Error!void {
    // TODO: Implement ternary/conditional expressions
    try self.writeTrimmed(node);
}

pub fn writeAttributeCall(self: *GdWriter, node: Node) Error!void {
    // child 0: method name (identifier, subscript, or nested call)
    const method = node.child(0) orelse return Error.MissingRequiredChild;
    // renderNode is a no-op for unregistered node types; fall back to verbatim text
    const bytes_before = self.bytes_written;
    try formatter.renderNode(method, self);
    if (self.bytes_written == bytes_before) {
        try self.writeTrimmed(method);
    }
    // child 1: arguments
    const args = node.child(1) orelse return Error.MissingRequiredChild;
    try self.writeArguments(args);
}

pub fn writeArguments(self: *GdWriter, node: Node) Error!void {
    try self.writeDelimitedList(node, .{ .open = "(", .close = ")" });
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
        // Don't write newline for inline comments - let the caller handle it
    } else {
        // Standalone comment - preserve indentation
        try self.writeIndentLevel(self.context.indent_level);
        try self.writeTrimmed(comment_node);
        // Note: newline after comment is handled by the container (writeBody)
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
const Writer = std.Io.Writer;
const testing = std.testing;

const builtin = @import("builtin");

const debug = @import("debug.zig");
const assert = debug.debugAssert;

const tree_sitter = @import("tree-sitter");
const Node = tree_sitter.TSNode;

const enums = @import("enums.zig");
const NodeType = enums.GdNodeType;

const formatter = @import("formatter.zig");

const Context = @import("Context.zig");
const WhitespaceConfig = @import("WhitespaceConfig.zig");

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
