# Ticket: Update writeBody for Comment Support

## Epic
Comment-Aware Processing

## Summary
Update `writeBody` to properly handle comments that appear between statements within class and function bodies.

## Description
Enhance the `writeBody` method to handle comments that can appear between any statements within a body block, ensuring proper indentation and formatting of both standalone and inline comments.

## Acceptance Criteria

### 1. Handle comments between statements
- [x] Process comment nodes found between statements in body
- [x] Maintain proper indentation for standalone comments
- [x] Handle inline comments appropriately (though they're less common in body contexts)
- [x] Preserve existing statement processing logic

### 2. Maintain body processing integrity
- [x] All existing statement types continue to work
- [x] Proper indentation and newline handling preserved
- [x] No regressions in current body formatting
- [x] Integration with existing `writeBody` fix for processing all children

### 3. Handle various comment patterns in bodies
- [x] Comments at the beginning of bodies
- [x] Comments between statements
- [x] Comments at the end of bodies
- [x] Multiple consecutive comments
- [x] Mixed comments and statements

### 4. Integration testing
- [x] Works correctly with class bodies
- [x] Works correctly with function bodies
- [x] Maintains proper nesting and indentation levels
- [x] No conflicts with existing statement processing

#### Comprehensive Body Comment Test Cases
- [x] **Comments at body start**: Comments as first elements in class/function bodies
- [x] **Comments between statements**: Comments interspersed with variable declarations, expressions
- [x] **Comments at body end**: Comments as last elements before closing structure
- [x] **Multiple consecutive comments**: Comment blocks within bodies
- [x] **Mixed comment patterns**: Combination of inline and standalone comments in same body
- [x] **Empty comments**: Comments with no content (`#`) within bodies
- [x] **Comments with special content**: Unicode, symbols, code examples within comments

#### Body-Specific Output Quality Validation
- [x] **Consistent indentation**: Comments indented to match their context level
- [x] **Statement separation**: Proper newlines between comments and statements
- [x] **Indentation preservation**: Statement indentation unaffected by comment processing
- [x] **Comment-statement association**: Clear visual association between comments and related code
- [x] **Nested structure support**: Comments work correctly in deeply nested bodies
- [x] **Content preservation**: All comment text preserved exactly as written

#### Advanced Integration Scenarios
- [x] **Class bodies with mixed content**: Classes containing properties, methods, and comments
- [x] **Function bodies with complex logic**: Functions with loops, conditionals, and comments
- [x] **Nested class/function combinations**: Comments in methods within classes
- [x] **Variable declaration comments**: Comments near variable assignments and declarations
- [x] **Control flow comments**: Comments within if/for/while statement bodies
- [x] **Multi-level nesting**: Comments at various indentation levels in deeply nested structures

## Implementation Notes

### Current writeBody Structure
The current `writeBody` method processes all children but may not handle comments properly:
```zig
pub fn writeBody(self: *GdWriter, node: Node) Error!void {
    // Process all children in the body
    for (0..node.childCount()) |i| {
        if (node.child(@intCast(i))) |child| {
            if (i > 0) {
                try self.writeNewline();
            }
            // Write proper indentation for the statement
            try formatter.writeIndent(self.writer, self.context);
            var cursor = child.cursor();
            try formatter.depthFirstWalk(&cursor, self);
        }
    }
}
```

### Enhanced Comment-Aware Implementation
```zig
pub fn writeBody(self: *GdWriter, node: Node) Error!void {
    assert(node.getTypeAsEnum(NodeType) == .body);

    for (0..node.childCount()) |i| {
        if (node.child(@intCast(i))) |child| {
            if (i > 0) {
                try self.writeNewline();
            }

            // Handle comments with proper indentation
            if (child.getTypeAsEnum(NodeType) == .comment) {
                try self.handleComment(child);
                continue;
            }

            // Handle regular statements
            try formatter.writeIndent(self.writer, self.context);
            var cursor = child.cursor();
            try formatter.depthFirstWalk(&cursor, self);
        }
    }
}
```

### Target Test Cases
```gd
class Example:
    # Comment at start of class body
    func first():
        pass

    # Comment between functions
    func second():
        # Comment at start of function body
        var x = 1
        # Comment between statements
        var y = 2
        # Comment at end of function body

# Comment at end of class body
```

## Files to Modify
- `src/GdWriter.zig` - Update `writeBody` method
- Existing test files that contain comments within bodies
- New test cases for comprehensive comment scenarios

## Dependencies
- #001: Core Comment Infrastructure
- #002: Update writeClassDefinition
- #003: Update writeFunctionDefinition

## Related Tickets
- #005: Comprehensive comment testing
- #006: Performance validation

## Special Considerations

### Interaction with Existing Fixes
This ticket builds on the previous fix where `writeBody` was updated to process all children instead of just the first one. The comment handling should integrate seamlessly with this existing improvement.

### Indentation Context
The `writeBody` method operates within an existing indentation context set by the parent (class or function). Comment handling must respect this context and not interfere with the indentation level management.

### Statement vs Comment Processing
The method needs to distinguish between:
- Regular statements that need indentation followed by formatter processing
- Comments that need special comment handling with appropriate indentation

## Estimated Effort
Small to Medium (1 day)

## Definition of Done
- [x] All acceptance criteria met
- [x] Comments in class bodies formatted correctly
- [x] Comments in function bodies formatted correctly
- [x] No regressions in statement processing
- [x] Proper indentation maintained throughout
- [x] Integration with existing `writeBody` fixes preserved
- [x] Code compiles without warnings

### Enhanced Body Comment Validation
- [x] **Multi-level indentation correctness**: Comments at all nesting levels properly indented
- [x] **Statement flow preservation**: Comments don't disrupt statement processing or formatting
- [x] **Content integrity**: All comment content preserved without modification
- [x] **Visual formatting quality**: Clear separation and association between comments and code
- [x] **Edge case handling**: Empty comments, special characters, very long comments

### Complex Scenario Testing
- [x] **Large body structures**: Bodies with many statements and comments
- [x] **Deeply nested scenarios**: Multiple levels of classes, functions, and control structures
- [x] **Mixed content bodies**: Bodies containing various GDScript constructs with comments
- [x] **Performance with comment-heavy bodies**: Bodies with high comment-to-code ratios

### Integration and Regression Validation
- [x] **Existing functionality preservation**: All current body processing features work correctly
- [x] **Cross-component compatibility**: Proper interaction with class and function definition processing
- [x] **Context management**: Indentation context correctly maintained across comment processing
- [x] **Error resilience**: Graceful handling of malformed or unexpected comment structures

### Quality Assurance Requirements
- [x] **Visual inspection**: Manual review of formatted output for various body scenarios
- [x] **Automated testing**: Comprehensive test coverage for all comment patterns in bodies
- [x] **Performance validation**: No significant performance impact from comment processing
- [x] **Code quality**: Implementation follows project patterns and conventions