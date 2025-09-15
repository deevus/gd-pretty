# Issue #002: Whitespace output should be consistent (all tabs or all spaces based on configuration)

## Issue Metadata
- **Issue Number**: 002
- **Issue Type**: Bug
- **Priority**: High
- **Effort**: Medium
- **Status**: Not Started

## Problem Statement
The gd-pretty formatter produces inconsistent whitespace output, mixing tabs and spaces within the same file. This violates coding standards and can cause issues with editors, linters, and version control systems that expect consistent indentation.

## Current Behavior
The formatter outputs mixed whitespace where some lines use spaces for indentation and others use tabs, even within the same scope or indentation level.

### Example
**Current Output in `compound_function_statements.out.gd`:**
```gdscript
class X:
    func foo():        # ← 4 spaces
        if true:       # ← 8 spaces
			pass           # ← tabs
			pass           # ← tabs
        if true:       # ← 8 spaces
			pass           # ← tabs
			pass           # ← tabs
		else:              # ← tabs
			pass           # ← tabs
			pass           # ← tabs
```

## Expected Behavior
The formatter should produce consistent whitespace output based on configuration:
- **Option 1**: All tabs for indentation
- **Option 2**: All spaces for indentation (with configurable width)
- **Option 3**: Detect and preserve the existing style in the input file

**Expected Output (all spaces example):**
```gdscript
class X:
    func foo():
        if true:
            pass
            pass
        if true:
            pass
            pass
        else:
            pass
            pass
```

## Steps to Reproduce
1. Run gd-pretty on `tests/input-output-pairs/compound_function_statements.in.gd`
2. Examine the output file with `cat -A` to see whitespace characters
3. Observe mixed tabs (`^I`) and spaces in the output

## Evidence
The issue is clearly visible in `tests/input-output-pairs/compound_function_statements.out.gd` where:
- Function and class declarations use spaces
- Statements within control structures use tabs
- This creates an inconsistent indentation pattern

## Acceptance Criteria
- [ ] Formatter produces consistent whitespace (either all tabs or all spaces)
- [ ] Configuration option to choose between tabs and spaces
- [ ] Configuration option to set space width (e.g., 2, 4, 8 spaces)
- [ ] Option to auto-detect and preserve existing style from input
- [ ] All existing tests pass with consistent whitespace
- [ ] No mixed tabs/spaces within the same file

## Implementation Notes
- Need to add configuration options for indentation style
- The `GdWriter.zig` likely needs updates to respect indentation configuration
- Consider adding CLI flags like `--indent-style=tabs|spaces` and `--indent-width=4`
- May need to update the context tracking for indentation
- Should handle both initial formatting and preserving existing style

## Configuration Options to Implement
1. **Indent Style**: `tabs` | `spaces` | `auto-detect`
2. **Indent Width**: Number (for spaces, default: 4)
3. **Preserve Style**: Boolean (auto-detect from input)

## Testing Requirements
- [ ] Test with all-tabs configuration
- [ ] Test with all-spaces configuration (various widths)
- [ ] Test auto-detection of existing style
- [ ] Verify `compound_function_statements` test passes with consistent output
- [ ] Test various indentation scenarios:
  - Nested functions
  - Class methods
  - Control structures (if/else, loops)
  - Mixed code structures
- [ ] Ensure no regression in other formatting features

## Definition of Done
- [ ] Configuration system implemented for indentation style
- [ ] CLI flags added for indentation options
- [ ] All output uses consistent whitespace (no mixed tabs/spaces)
- [ ] All existing tests pass with updated expected output
- [ ] Documentation updated with new configuration options
- [ ] Manual testing confirms consistent output across various code patterns

## Related Files
- `tests/input-output-pairs/compound_function_statements.in.gd`
- `tests/input-output-pairs/compound_function_statements.out.gd`
- `src/GdWriter.zig` (indentation logic)
- `src/main.zig` (CLI argument parsing)
- `src/formatter.zig` (context management)