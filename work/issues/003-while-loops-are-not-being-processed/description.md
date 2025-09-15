# Issue #003: While loops are not being processed

## Issue Metadata
- **Issue Number**: 003
- **Issue Type**: Bug
- **Priority**: High
- **Effort**: Small
- **Status**: Not Started

## Problem Statement
The gd-pretty formatter completely omits `while` loops from the output, causing loss of code functionality. This is a critical bug that results in invalid/incomplete code output.

## Current Behavior
When the formatter encounters a `while` loop in the input, it completely skips processing it and excludes it from the output entirely.

### Example
**Input:**
```gdscript
class X:
    func foo():
        while true:
            pass
            pass
        for i in range(10):
            break
            continue
```

**Current Output:**
```gdscript
class X:
    func foo():

        for i in range(10):
            break
            continue
```

**Notice**: The entire `while` loop and its body are missing from the output.

## Expected Behavior
While loops should be properly formatted and included in the output with correct indentation and structure.

**Expected Output:**
```gdscript
class X:
    func foo():
        while true:
            pass
            pass
        for i in range(10):
            break
            continue
```

## Steps to Reproduce
1. Create a GDScript file containing a `while` loop
2. Run gd-pretty on the file
3. Observe that the `while` loop is completely missing from the output

## Evidence
This issue is demonstrated in `tests/input-output-pairs/compound_function_statements.out.gd` where the `while` loop from the input file is entirely absent from the output.

## Root Cause Analysis
The formatter likely lacks a handler for `while` loop nodes in the AST processing. This could be due to:
- Missing `while_statement` case in the node type handling
- Unimplemented `writeWhileStatement` method in `GdWriter.zig`
- `while_statement` not being mapped in the compile-time node routing

## Acceptance Criteria
- [ ] While loops are properly processed and included in the output
- [ ] While loop formatting matches the established indentation and spacing rules
- [ ] While loop bodies are correctly indented
- [ ] Nested while loops are handled correctly
- [ ] All existing tests pass
- [ ] The `compound_function_statements` test includes the while loop in output

## Implementation Notes
- Add `while_statement` to the `GdNodeType` enum in `src/enums.zig`
- Implement `writeWhileStatement` method in `src/GdWriter.zig`
- Follow the pattern used for other control structures (if/for statements)
- Ensure proper handling of:
  - While condition expression
  - While body block
  - Indentation and spacing
  - Nested structures

## Testing Requirements
- [ ] Verify the `compound_function_statements` test passes with while loop included
- [ ] Test various while loop patterns:
  - Simple while loops
  - Nested while loops
  - While loops with complex conditions
  - While loops with different body content
  - While loops mixed with other control structures
- [ ] Ensure no regression in other control structure formatting

## Definition of Done
- [ ] While loops are processed and included in formatter output
- [ ] While loop formatting is consistent with other control structures
- [ ] All existing tests pass
- [ ] The `compound_function_statements.out.gd` test output includes the while loop
- [ ] Manual testing confirms while loops work in various scenarios
- [ ] No code functionality is lost during formatting

## Related Files
- `tests/input-output-pairs/compound_function_statements.in.gd`
- `tests/input-output-pairs/compound_function_statements.out.gd`
- `src/enums.zig` (add `while_statement` node type)
- `src/GdWriter.zig` (implement `writeWhileStatement` method)
- `src/formatter.zig` (ensure proper node routing)