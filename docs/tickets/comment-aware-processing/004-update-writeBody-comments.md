# Ticket: Update writeBody for Comment Support

## Epic
Comment-Aware Processing

## Summary
Update `writeBody` to properly handle comments that appear between statements within class and function bodies.

## Description
Enhance the `writeBody` method to handle comments that can appear between any statements within a body block, ensuring proper indentation and formatting of both standalone and inline comments.

## Acceptance Criteria

### 1. Handle comments between statements
- [ ] Process comment nodes found between statements in body
- [ ] Maintain proper indentation for standalone comments
- [ ] Handle inline comments appropriately (though they're less common in body contexts)
- [ ] Preserve existing statement processing logic

### 2. Maintain body processing integrity
- [ ] All existing statement types continue to work
- [ ] Proper indentation and newline handling preserved
- [ ] No regressions in current body formatting
- [ ] Integration with existing `writeBody` fix for processing all children

### 3. Handle various comment patterns in bodies
- [ ] Comments at the beginning of bodies
- [ ] Comments between statements
- [ ] Comments at the end of bodies
- [ ] Multiple consecutive comments
- [ ] Mixed comments and statements

### 4. Integration testing
- [ ] Works correctly with class bodies
- [ ] Works correctly with function bodies
- [ ] Maintains proper nesting and indentation levels
- [ ] No conflicts with existing statement processing

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
- [ ] All acceptance criteria met
- [ ] Comments in class bodies formatted correctly
- [ ] Comments in function bodies formatted correctly
- [ ] No regressions in statement processing
- [ ] Proper indentation maintained throughout
- [ ] Integration with existing `writeBody` fixes preserved
- [ ] Code compiles without warnings