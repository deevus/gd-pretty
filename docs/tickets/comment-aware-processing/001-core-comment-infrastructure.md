# Ticket: Core Comment Infrastructure

## Epic
Comment-Aware Processing

## Summary
Implement the foundational comment handling infrastructure in GdWriter to support runtime comment processing.

## Description
Add the core `handleComment()` method and supporting utilities to GdWriter that can classify and format different types of comments (inline vs standalone) according to the architecture defined in ADR-002.

## Acceptance Criteria

### 1. Add `handleComment()` method to GdWriter
- [ ] Method signature: `fn handleComment(self: *GdWriter, comment_node: Node) Error!void`
- [ ] Handles inline comments with proper spacing (space before comment, newline after)
- [ ] Handles standalone comments with proper indentation
- [ ] Preserves original comment content using `writeTrimmed()`

### 2. Add comment classification utilities
- [ ] `isInlineComment(comment_node: Node) bool` function
- [ ] Logic to determine if comment appears on same line as previous content
- [ ] Consider node position and source text analysis for classification

### 3. Improve error handling for unknown node types
- [ ] Update existing force unwrap `.?` calls to use `orelse` with graceful fallback
- [ ] Add debug logging for unknown node types
- [ ] Fallback to treating unknown nodes as comments when appropriate

### 4. Basic testing
- [ ] Unit tests for `handleComment()` with both inline and standalone comments
- [ ] Unit tests for `isInlineComment()` classification
- [ ] Test error handling with unknown node types

## Implementation Notes

### handleComment() Implementation
```zig
fn handleComment(self: *GdWriter, comment_node: Node) Error!void {
    assert(comment_node.getTypeAsEnum(NodeType) == .comment);

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

### Error Handling Pattern
Replace patterns like:
```zig
const param_type = (param.getTypeAsEnum(NodeType)).?;
```

With:
```zig
const param_type = param.getTypeAsEnum(NodeType) orelse {
    log.debug("Unknown node type: '{s}', treating as comment", .{param.getTypeAsString()});
    try self.handleComment(param);
    continue;
};
```

## Files to Modify
- `src/GdWriter.zig` - Add new methods and improve error handling
- `src/GdWriter.zig` (tests) - Add unit tests for new functionality

## Dependencies
- None (foundational ticket)

## Related Tickets
- #002: Update writeClassDefinition for comments
- #003: Update writeFunctionDefinition for comments
- #004: Update writeBody for comments

## Estimated Effort
Medium (1-2 days)

## Definition of Done
- [x] All acceptance criteria met
- [x] Code compiles without warnings
- [x] Unit tests pass
- [x] Basic comment handling works in isolation
- [x] Debug logging provides useful information for unknown nodes
