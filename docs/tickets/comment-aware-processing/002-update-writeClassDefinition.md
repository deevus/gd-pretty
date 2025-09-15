# Ticket: Update writeClassDefinition for Comment Support

## Epic
Comment-Aware Processing

## Summary
Update `writeClassDefinition` to handle comments between structural elements, particularly between the colon (`:`) and the class body.

## Description
Replace the rigid direct indexing approach in `writeClassDefinition` with the flexible skip-and-process pattern that can handle comments appearing between the class declaration colon and the body node.

## Acceptance Criteria

### 1. Implement skip-and-process pattern
- [ ] Replace direct `node.child(i)` access for body with iterative approach
- [ ] Handle `.comment` nodes by calling `handleComment()`
- [ ] Find and process `.body` node after handling any intermediate comments
- [ ] Maintain proper error handling for unexpected node types

### 2. Preserve existing functionality
- [ ] All existing class definition formatting behavior preserved
- [ ] Proper indentation and structure maintained
- [ ] No regressions in existing test cases

### 3. Handle edge cases
- [ ] Multiple consecutive comments between `:` and body
- [ ] Empty comment content
- [ ] Mixed inline and standalone comments
- [ ] No comments (original behavior preserved)

### 4. Add comprehensive testing
- [ ] Test `class X: # comment` inline comment case
- [ ] Test multiple comments between colon and body
- [ ] Test existing functionality still works (regression testing)
- [ ] Update or create snapshot tests for comment scenarios

## Implementation Notes

### Pattern Transformation
Replace this rigid approach:
```zig
// Current failing code
const body_node = node.child(i) orelse return Error.MissingRequiredChild;
if (body_node.getTypeAsEnum(NodeType) != .body) {
    log.err("Expected body node, got {s}", .{body_node.getTypeAsString()});
    return Error.UnexpectedNodeType;
}
try self.writeBody(body_node);
```

With this flexible approach:
```zig
// New comment-aware code
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
            try self.writeBody(child);
            found_body = true;
            break;
        },
        else => {
            log.err("Expected body or comment after class declaration, got {s}", .{child.getTypeAsString()});
            return Error.UnexpectedNodeType;
        }
    }
}

if (!found_body) {
    return Error.MissingRequiredChild;
}
```

### Target Test Case
The implementation should successfully format:
```gd
class X: # inline comment
    func foo():
        pass
```

Expected output:
```gd
class X: # inline comment
    func foo():
        pass
```

## Files to Modify
- `src/GdWriter.zig` - Update `writeClassDefinition` method
- `tests/input-output-pairs/inline_comments_on_compound_stmts.in.gd` - Use as test case
- Add new test cases for various comment scenarios

## Dependencies
- #001: Core Comment Infrastructure (must be completed first)

## Related Tickets
- #003: Update writeFunctionDefinition for comments
- #004: Update writeBody for comments
- #005: Comprehensive comment testing

## Estimated Effort
Small (0.5-1 day)

## Definition of Done
- [ ] All acceptance criteria met
- [ ] `inline_comments_on_compound_stmts.in.gd` test passes
- [ ] No regressions in existing class definition tests
- [ ] Code compiles without warnings
- [ ] Proper error handling and logging implemented
- [ ] Comment classification works correctly (inline vs standalone)