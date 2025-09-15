# ADR-002: Comment-Aware Node Processing

## Status

Proposed

## Context

The gd-pretty GDScript formatter currently fails when comments appear between expected structural AST nodes. The formatter assumes a rigid AST structure where specific node types appear at fixed positions, but tree-sitter includes comment nodes within the AST structure, causing crashes when comments appear in "unexpected" locations.

### Current Problem

The formatter crashes on valid GDScript code like:

```gd
class X: # inline comment
    func foo(): # another comment
        pass
```

**Error**: `Expected body node, got comment`

The issue occurs in methods like `writeClassDefinition` and `writeFunctionDefinition` that expect:
1. Structural elements (class, name, colon)
2. Immediately followed by `body` node

But tree-sitter's AST includes comment nodes between the colon and body:
1. `class` keyword
2. `name` node
3. `:` colon
4. `comment` node (the inline comment)
5. `body` node

### Research Findings

We evaluated how established formatters handle comments in AST processing:

#### Ruff (Python Formatter)
- **Preprocessing approach**: Comments extracted during AST traversal and associated with nodes
- **Comment classification**: Leading, Dangling, and Trailing comments
- **Storage**: Centralized `Comments` structure with node mapping
- **Processing time**: Before formatting begins

#### Zig fmt
- **Runtime approach**: Comments handled during rendering/output phase
- **Token-level detection**: `hasComment()`, `hasSameLineComment()` functions
- **Processing time**: During output generation
- **Strategy**: In-place preservation with minimal restructuring

## Decision

We chose the **Runtime Comment Processing** approach inspired by Zig fmt, using a "skip-and-process" strategy during node writing.

## Architecture

### Core Strategy

Instead of expecting rigid AST structure, iterate through child nodes and handle comments as encountered, then continue to find expected structural nodes.

### Pattern Transformation

**Before (Rigid):**
```zig
pub fn writeClassDefinition(self: *GdWriter, node: Node) Error!void {
    // ... write class, name, colon ...

    // FAILS when comment present
    const body_node = node.child(i) orelse return Error.MissingRequiredChild;
    if (body_node.getTypeAsEnum(NodeType) != .body) {
        return Error.UnexpectedNodeType;  // <- CRASHES HERE
    }
    try self.writeBody(body_node);
}
```

**After (Flexible):**
```zig
pub fn writeClassDefinition(self: *GdWriter, node: Node) Error!void {
    // ... write class, name, colon ...

    // Handle any intermediate comments, then find body
    var current_index = i;
    while (current_index < node.childCount()) {
        const child = node.child(current_index) orelse break;

        switch (child.getTypeAsEnum(NodeType) orelse .unknown) {
            .comment => {
                try self.handleComment(child);
                current_index += 1;
                continue;
            },
            .body => {
                try self.writeBody(child);
                break;
            },
            else => {
                log.err("Expected body or comment, got {s}", .{child.getTypeAsString()});
                return Error.UnexpectedNodeType;
            }
        }
    }
}
```

### Implementation Components

#### 1. Comment Handler Method
```zig
fn handleComment(self: *GdWriter, comment_node: Node) Error!void {
    // Determine comment type and apply appropriate formatting
    if (isInlineComment(comment_node)) {
        try self.write(" ", .{});  // space before inline comment
        try self.writeTrimmed(comment_node);
        try self.writeNewline();
    } else {
        // Standalone comment - preserve indentation
        try formatter.writeIndent(self.writer, self.context);
        try self.writeTrimmed(comment_node);
        try self.writeNewline();
    }
}
```

#### 2. Comment Classification
```zig
fn isInlineComment(comment_node: Node) bool {
    // Check if comment appears on same line as previous content
    // Implementation based on node position analysis
}
```

#### 3. Updated Error Handling
```zig
// Improved null pointer handling for unknown node types
const node_type = child.getTypeAsEnum(NodeType) orelse {
    log.debug("Unknown node type: '{s}', processing as comment", .{child.getTypeAsString()});
    try self.handleComment(child);
    continue;
};
```

## Rationale

### Why Runtime Processing Over Preprocessing

1. **Compatibility with Tree-sitter**: Tree-sitter already provides comments as AST nodes, no need to extract and reassociate them

2. **Simplicity**: less implementation complexity
   - No comment extraction phase
   - No complex node association logic
   - No separate comment storage system

3. **Predictable Behavior**: Comments handled exactly where they appear in the AST
   - Preserves original programmer intent
   - No ambiguity about comment placement
   - Deterministic output

4. **Maintainability**: Clear, linear processing flow
   - Each structural method handles its own comments
   - No global state management
   - Easy to debug and extend

### Why Skip-and-Process Over Error Propagation

1. **Robustness**: Handles comments anywhere they can legally appear
2. **Performance**: No exception overhead for normal comment processing
3. **Extensibility**: Pattern works for any structural node type
4. **Clarity**: Explicit handling rather than implicit error recovery

## Implementation Strategy

### Phase 1: Core Infrastructure

1. **Add `handleComment()` method** to GdWriter
   - Comment type detection (inline vs standalone)
   - Appropriate spacing and indentation
   - Preserve comment content

2. **Update critical structural methods**:
   - `writeClassDefinition`: Handle comments between `:` and `body`
   - `writeFunctionDefinition`: Handle comments between parameters and `body`
   - `writeBody`: Handle comments between statements

3. **Improve error handling**:
   - Graceful handling of unknown node types
   - Better logging for debugging
   - Fallback to generic comment processing

### Phase 2: Comprehensive Coverage

4. **Extend to other structural methods** as needed
5. **Add comprehensive test coverage** for comment scenarios using snapshot testing
6. **Performance validation** with large files containing many comments

### Example Implementation Flow

```zig
// Generic pattern for structural methods
fn writeStructuralNode(self: *GdWriter, node: Node) Error!void {
    // ... write fixed structural elements ...

    // Find expected child node, handling any intermediate comments
    var current_index = expected_child_index;
    var found_target = false;

    while (current_index < node.childCount()) {
        const child = node.child(current_index) orelse break;

        switch (child.getTypeAsEnum(NodeType) orelse .unknown) {
            .comment => {
                try self.handleComment(child);
            },
            .expected_target_type => {
                try self.writeTargetNode(child);
                found_target = true;
                break;
            },
            else => {
                return Error.UnexpectedNodeType;
            }
        }
        current_index += 1;
    }

    if (!found_target) {
        return Error.MissingRequiredChild;
    }
}
```

## Consequences

### Positive

- **Robustness**: Handles comments in any valid position without crashing
- **Simplicity**: Minimal code changes to existing structure
- **Maintainability**: Clear, predictable processing logic
- **Extensibility**: Easy to add comment support to new node types
- **Performance**: No preprocessing overhead
- **Correctness**: Preserves original comment placement and formatting

### Negative

- **Slightly More Complex Control Flow**: Loop-based instead of direct indexing
- **Pattern Repetition**: Similar comment-handling logic across multiple methods

### Neutral

- **Testing Strategy**: Need to validate comment scenarios across all structural types
- **Backwards Compatibility**: No impact on existing functionality

## Alternatives Considered

### 1. Ruff-Style Preprocessing
```zig
// Collect comments during initial AST traversal
const comments = collectComments(tree);
// Associate comments with structural nodes
const comment_map = associateComments(comments, ast_nodes);
// Process during formatting
const node_comments = comment_map.get(current_node);
```

**Rejected because**:
- Complex to implement with tree-sitter AST structure
- Requires duplicate AST traversal
- Difficult to determine correct comment association
- Adds global state management complexity

### 2. AST Transformation
```zig
// Remove comments from structural processing
const cleaned_ast = removeComments(original_ast);
const comments = extractComments(original_ast);
// Process separately
formatStructure(cleaned_ast);
insertComments(comments);
```

**Rejected because**:
- Requires AST modification capabilities
- Complex comment reinsertion logic
- Potential for lost or misplaced comments
- High implementation complexity

### 3. Token-Stream Processing
```zig
// Process raw token stream instead of AST
while (hasNextToken()) {
    const token = nextToken();
    if (token.type == .comment) {
        handleComment(token);
    } else {
        handleStructuralToken(token);
    }
}
```

**Rejected because**:
- Loses AST structure benefits
- Requires reimplementing parsing logic
- Breaks abstraction boundaries
- Much more complex than current approach

## Test Cases

The implementation must handle these scenarios:

```gd
// Inline comments after structural elements
class X: # comment
    pass

func foo(): # comment
    pass

// Comments between statements
class Y:
    # standalone comment
    func bar():
        pass
    # another comment
    func baz():
        pass

// Multiple consecutive comments
class Z:
    # comment 1
    # comment 2
    # comment 3
    func qux():
        pass

// Mixed inline and standalone
class W: # inline
    # standalone
    func method(): # inline
        # standalone
        pass
```

## References

- [Ruff Formatter Comment Handling](https://github.com/astral-sh/ruff/tree/main/crates/ruff_python_formatter/src/comments)
- [Zig AST Renderer](https://github.com/ziglang/zig/blob/master/lib/std/zig/Ast/Render.zig)
- [Tree-sitter GDScript Grammar](https://github.com/PrestonKnopp/tree-sitter-gdscript)
- [Test Cases: inline_comments_on_compound_stmts.in.gd](../../tests/input-output-pairs/inline_comments_on_compound_stmts.in.gd)

## Revision History

- **2025-01-XX**: Initial decision record created
- **Status**: Proposed for implementation
