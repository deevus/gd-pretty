# Ticket: Update writeFunctionDefinition for Comment Support

## Epic
Comment-Aware Processing

## Summary
Update `writeFunctionDefinition` to handle comments between the function signature (parameters, colon) and the function body.

## Description
Apply the same skip-and-process pattern used in `writeClassDefinition` to `writeFunctionDefinition`, enabling it to handle comments that appear between the function declaration and body.

## Acceptance Criteria

### 1. Implement skip-and-process pattern for function bodies
- [ ] Replace direct body node access with iterative comment-aware approach
- [ ] Handle `.comment` nodes between function signature and body
- [ ] Find and process `.body` node after handling intermediate comments
- [ ] Maintain existing function signature formatting behavior

### 2. Handle function-specific comment scenarios
- [ ] Comments after parameter list and colon: `func foo(): # comment`
- [ ] Multiple comments between signature and body
- [ ] Comments with various indentation levels
- [ ] Preserve existing function formatting for non-comment cases

### 3. Maintain parameter processing integrity
- [ ] Existing parameter handling logic unchanged
- [ ] No impact on parameter comment handling (if any)
- [ ] Function name, static keywords, and signature processing preserved

### 4. Add targeted testing
- [ ] Test `func foo(): # comment` scenario
- [ ] Test functions with no comments (regression testing)
- [ ] Test multiple comments before function body
- [ ] Integration with class methods and standalone functions

## Implementation Notes

### Current Issue Location
The issue occurs in the function body processing section of `writeFunctionDefinition`:
```zig
// Current code that needs updating
const body_node = node.child(i) orelse return Error.MissingRequiredChild;
assert(body_node.getTypeAsEnum(NodeType) == .body);

// This section needs the comment-aware pattern
```

### Implementation Pattern
Apply the same pattern used in `writeClassDefinition`:
```zig
// Find body node, handling any intermediate comments
var current_index = i;
var found_body = false;

while (current_index < node.childCount()) {
    const child = node.child(current_index) orelse break;

    switch (child.getTypeAsEnum(NodeType) orelse .unknown) {
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
            log.err("Expected body or comment after function signature, got {s}", .{child.getTypeAsString()});
            return Error.UnexpectedNodeType;
        }
    }
}

if (!found_body) {
    return Error.MissingRequiredChild;
}
```

### Target Test Cases
```gd
# Inline comment after function signature
func foo(): # this is a comment
    pass

# Multiple comments
func bar():
    # standalone comment
    # another comment
    pass

# Method with inline comment
class X:
    func method(): # comment
        pass
```

## Files to Modify
- `src/GdWriter.zig` - Update `writeFunctionDefinition` method
- Test files for function-specific comment scenarios

## Dependencies
- #001: Core Comment Infrastructure
- #002: Update writeClassDefinition (for pattern consistency)

## Related Tickets
- #004: Update writeBody for comments
- #005: Comprehensive comment testing

## Estimated Effort
Small (0.5-1 day)

## Definition of Done
- [ ] All acceptance criteria met
- [ ] Function signature comments handled correctly
- [ ] No regressions in existing function formatting
- [ ] Integration tests pass for methods within classes
- [ ] Standalone function comments work correctly
- [ ] Code compiles without warnings
- [ ] Proper indentation maintained in function bodies