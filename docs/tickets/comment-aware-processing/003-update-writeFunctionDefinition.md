# Ticket: Update writeFunctionDefinition for Comment Support

## Epic
Comment-Aware Processing

## Summary
Update `writeFunctionDefinition` to handle comments between the function signature (parameters, colon) and the function body.

## Description
Apply the same skip-and-process pattern used in `writeClassDefinition` to `writeFunctionDefinition`, enabling it to handle comments that appear between the function declaration and body.

## Acceptance Criteria

### 1. Implement skip-and-process pattern for function bodies
- [x] Replace direct body node access with iterative comment-aware approach
- [x] Handle `.comment` nodes between function signature and body
- [x] Find and process `.body` node after handling intermediate comments
- [x] Maintain existing function signature formatting behavior

### 2. Handle function-specific comment scenarios
- [x] Comments after parameter list and colon: `func foo(): # comment`
- [x] Multiple comments between signature and body
- [x] Comments with various indentation levels
- [x] Preserve existing function formatting for non-comment cases

### 3. Maintain parameter processing integrity
- [x] Existing parameter handling logic unchanged
- [x] No impact on parameter comment handling (if any)
- [x] Function name, static keywords, and signature processing preserved

### 4. Add targeted testing
- [x] Test `func foo(): # comment` scenario
- [x] Test functions with no comments (regression testing)
- [x] Test multiple comments before function body
- [x] Integration with class methods and standalone functions

#### Comprehensive Function Comment Test Cases
- [x] **Inline comments after function signature**: `func foo(): # comment`
- [x] **Comments after parameter lists**: `func bar(x: int): # parameter comment`
- [x] **Multiple consecutive comments**: Comments between signature and body
- [x] **Static function comments**: `static func example(): # static comment`
- [x] **Function with return type comments**: `func baz() -> int: # return comment`
- [x] **Empty comment content**: `func test(): #` (edge case)
- [x] **Comments with special characters**: Unicode, symbols, code snippets

#### Function-Specific Output Quality Validation
- [x] **Inline comment positioning**: Comments stay on same line as function signature
- [x] **Proper spacing**: Exactly one space before inline comments
- [x] **Function body indentation**: Proper indentation maintained after comment processing
- [x] **Parameter preservation**: No impact on parameter formatting
- [x] **Return type preservation**: Return type annotations remain correctly formatted
- [x] **Static keyword preservation**: Static functions remain properly formatted

#### Integration Testing Scenarios
- [x] **Class method comments**: Function comments within class definitions
- [x] **Standalone function comments**: Top-level function comments
- [x] **Nested function scenarios**: Functions with complex parameter structures
- [x] **Mixed comment types**: Combination of inline and standalone comments
- [x] **Function overloading**: Comments with functions that have similar signatures

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
- [x] All acceptance criteria met
- [x] Function signature comments handled correctly
- [x] No regressions in existing function formatting
- [x] Integration tests pass for methods within classes
- [x] Standalone function comments work correctly
- [x] Code compiles without warnings
- [x] Proper indentation maintained in function bodies

### Enhanced Quality Validation
- [x] **Visual output inspection**: All function comment scenarios produce correct format
- [x] **Indentation verification**: Function bodies maintain proper indentation after comment processing
- [x] **Comment positioning accuracy**: Inline comments remain on signature line with correct spacing
- [x] **Parameter formatting preservation**: Parameter lists unaffected by comment processing
- [x] **Return type handling**: Return type annotations remain properly formatted
- [x] **Static function support**: Static functions with comments format correctly

### Regression Testing Requirements
- [x] **Existing function tests**: All current function definition tests continue to pass
- [x] **Class method integration**: Function comments work correctly within classes
- [x] **Complex signature handling**: Functions with parameters, return types, and modifiers
- [x] **Edge case robustness**: Empty comments, special characters, and malformed input

### Integration Validation
- [x] **Cross-component compatibility**: Works correctly with class definition and body processing
- [x] **Context preservation**: Indentation context properly maintained and passed down
- [x] **Error handling consistency**: Graceful handling of unexpected scenarios
- [x] **Performance impact**: No significant slowdown in function processing