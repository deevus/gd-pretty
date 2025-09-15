# Issue #001: Blank lines are erroneously inserted after line comments

## Issue Metadata
- **Issue Number**: 001
- **Issue Type**: Bug
- **Priority**: Medium
- **Effort**: Small
- **Status**: Not Started

## Problem Statement
The gd-pretty formatter is incorrectly inserting blank lines after line comments (comments that appear on their own line within function bodies). This creates unnecessary whitespace and deviates from the original code structure.

## Current Behavior
When formatting GDScript files with line comments inside function bodies, the formatter adds extra blank lines after each line comment.

### Example
**Input:**
```gdscript
func multiple():
    # first comment
    # second comment
    pass
```

**Current Output:**
```gdscript
func multiple():
    # first comment

    # second comment

    pass
```

## Expected Behavior
The formatter should preserve the original spacing and not insert blank lines after line comments.

**Expected Output:**
```gdscript
func multiple():
    # first comment
    # second comment
    pass
```

## Steps to Reproduce
1. Create a GDScript file with a function containing line comments within the function body
2. Run gd-pretty on the file
3. Observe that blank lines are inserted after each line comment

## Evidence
This issue is demonstrated in the test file `tests/input-output-pairs/function_comments_comprehensive.out.gd` in the `multiple()` function where blank lines are erroneously inserted between consecutive line comments.

## Acceptance Criteria
- [ ] Line comments within function bodies do not have blank lines inserted after them
- [ ] The original spacing structure between consecutive line comments is preserved
- [ ] All existing tests in `function_comments_comprehensive` pass
- [ ] No regression in other comment formatting scenarios

## Implementation Notes
- This likely involves the comment handling logic in the `GdWriter.zig` file
- The issue may be in how the formatter processes line comments within function bodies
- Need to investigate comment processing methods and newline insertion logic
- The problem specifically affects line comments (standalone comments on their own line), not inline comments

## Testing Requirements
- [ ] Verify the `function_comments_comprehensive` test passes with correct spacing
- [ ] Test various line comment patterns:
  - Consecutive line comments
  - Line comments mixed with code
  - Line comments at different indentation levels
- [ ] Ensure inline comments (end-of-line comments) are unaffected

## Definition of Done
- [ ] Blank lines are no longer inserted after line comments
- [ ] All existing tests pass
- [ ] The `function_comments_comprehensive.out.gd` test output matches expected formatting without extra blank lines
- [ ] Code changes are minimal and focused on the specific issue
- [ ] Manual testing confirms the fix works for various line comment scenarios

## Related Files
- `tests/input-output-pairs/function_comments_comprehensive.in.gd`
- `tests/input-output-pairs/function_comments_comprehensive.out.gd`
- `src/GdWriter.zig` (likely location of the bug)
- `src/formatter.zig` (comment processing logic)