# Ticket: Core Comment Infrastructure

## Epic
Comment-Aware Processing

## Summary
Implement the foundational comment handling infrastructure in GdWriter to support runtime comment processing.

## Description
Add the core `handleComment()` method and supporting utilities to GdWriter that can classify and format different types of comments (inline vs standalone) according to the architecture defined in ADR-002.

## Acceptance Criteria

### 1. Add `handleComment()` method to GdWriter
- [x] Method signature: `fn handleComment(self: *GdWriter, comment_node: Node) Error!void`
- [x] Handles inline comments with proper spacing (space before comment, newline after)
- [x] Handles standalone comments with proper indentation
- [x] Preserves original comment content using `writeTrimmed()`

### 2. Add comment classification utilities
- [x] `isInlineComment(comment_node: Node) bool` function
- [x] Logic to determine if comment appears on same line as previous content
- [x] Consider node position and source text analysis for classification

### 3. Improve error handling for unknown node types
- [x] Update existing force unwrap `.?` calls to use `orelse` with graceful fallback
- [x] Add debug logging for unknown node types
- [x] Fallback to treating unknown nodes as comments when appropriate

### 4. Basic testing
- [x] Unit tests for `handleComment()` with both inline and standalone comments
- [x] Unit tests for `isInlineComment()` classification
- [x] Test error handling with unknown node types

#### Comprehensive Test Cases for Core Infrastructure
- [x] **Inline comment handling**: Comments that appear on same line as code
- [x] **Standalone comment handling**: Comments that appear on their own lines
- [x] **Empty comments**: Comments with no content (`#`)
- [x] **Comments with special characters**: Unicode, symbols, code snippets
- [x] **Very long comments**: Comments that might affect line width
- [x] **Multiple consecutive comments**: Handling of comment blocks
- [x] **Comment content preservation**: Exact preservation of original text

#### Output Format Validation
- [x] **Inline comment formatting**: Space before comment, newline after
- [x] **Standalone comment formatting**: Proper indentation based on context
- [x] **Content preservation**: No modification of comment text
- [x] **Whitespace handling**: Proper spacing and indentation
- [x] **Newline consistency**: Consistent newline handling across comment types

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

### Additional Validation for Completed Infrastructure
Since this foundational ticket is marked as completed, thorough validation is critical:

#### Core Functionality Verification
- [x] **`handleComment()` correctness**: Verify correct handling of inline vs standalone comments
- [x] **`isInlineComment()` accuracy**: Test classification logic with various comment patterns
- [x] **Error handling robustness**: Ensure graceful handling of edge cases and unknown nodes
- [x] **Memory management**: No memory leaks or excessive allocations in comment processing

#### Integration Readiness
- [x] **API consistency**: Methods provide clean interface for higher-level components
- [x] **Context handling**: Proper interaction with indentation and formatting context
- [x] **Performance baseline**: No significant overhead introduced by core infrastructure
- [x] **Extensibility**: Infrastructure supports future comment-related features

#### Quality Assurance
- [x] **Code review**: Implementation follows project patterns and conventions
- [x] **Documentation**: Internal documentation explains classification logic and usage
- [x] **Test coverage**: Comprehensive coverage of all code paths and edge cases
- [x] **Regression testing**: Does not break existing formatter functionality
