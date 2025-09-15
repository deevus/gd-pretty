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

#### Specific Test Cases Required
- [ ] **Inline comment after class declaration**: `class X: # comment`
- [ ] **Multiple consecutive comments**: Multiple comments between `:` and body
- [ ] **Empty comment content**: `class X: #` (edge case)
- [ ] **Comments with special characters**: Unicode, symbols, mixed content
- [ ] **Mixed inline and standalone comments**: Complex comment patterns
- [ ] **No comments**: Original behavior preserved (regression testing)

#### Output Quality Validation
- [ ] **Proper indentation**: Comments maintain consistent indentation with class structure
- [ ] **Spacing consistency**: Exactly one space before inline comments (`class X: # comment`)
- [ ] **Newline handling**: Proper newline placement after comments
- [ ] **Comment content preservation**: Original comment text preserved exactly
- [ ] **No formatting artifacts**: No extra spaces, missing characters, or malformed output

#### Integration Testing
- [ ] **Nested classes**: Comments in nested class structures
- [ ] **Classes with multiple methods**: Comment handling doesn't affect method processing
- [ ] **Class inheritance**: Comments with extends/inherits syntax
- [ ] **Complex class bodies**: Mixed statements, properties, and comments

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

#### Current Issue Analysis
The current output from `inline_comments_on_compound_stmts.out.gd` shows:
```gd
pass

class X:
 # aaa
        func foo():
 # bbb
                pass
```

**Critical Issues to Fix:**
- [ ] **Incorrect indentation**: Comments should be properly indented relative to their context
- [x] **Missing inline comment positioning**: `class X: # aaa` should keep comment on same line
- [ ] **Broken comment-to-code association**: Comments appear disconnected from their associated elements
- [ ] **Excessive indentation**: Function and statements have incorrect indentation levels
- [x] **Missing proper spacing**: No space before inline comments

#### Quality Validation Criteria
- [ ] **Inline comments**: Must appear on same line as associated declaration with exactly one space before `#`
- [ ] **Standalone comments**: Must be indented to match the level of the next statement
- [ ] **Consistent indentation**: All elements maintain proper relative indentation (4 spaces per level)
- [ ] **No extra whitespace**: No trailing spaces, excessive blank lines, or formatting artifacts

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
- [ ] `inline_comments_on_compound_stmts.in.gd` test passes with correct output format
- [ ] No regressions in existing class definition tests
- [x] Code compiles without warnings
- [x] Proper error handling and logging implemented
- [x] Comment classification works correctly (inline vs standalone)

### Output Quality Verification
- [ ] **Visual inspection**: Output matches expected format exactly
- [ ] **Indentation validation**: All indentation levels are consistent and correct
- [ ] **Comment positioning**: Inline comments on same line, standalone comments properly indented
- [ ] **Spacing validation**: Exactly one space before inline comments, no trailing whitespace
- [ ] **Content preservation**: All comment content preserved exactly as in input
- [ ] **Structure integrity**: Class and method structure remains correct after comment processing

### Additional Validation for Completed Work
Since this ticket is marked as potentially completed, additional validation is required:
- [ ] **Re-run existing tests**: Verify all existing class definition tests still pass
- [ ] **Manual output inspection**: Review generated `.out.gd` files for quality issues
- [ ] **Edge case testing**: Test with various comment patterns and content types
- [ ] **Integration verification**: Ensure compatibility with other formatter features