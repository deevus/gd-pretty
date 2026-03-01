# TODO.md

This file tracks improvements needed for the gd-pretty GDScript formatter.

*Last updated: March 1, 2026*

## Critical Issues

None currently.

## High Priority Features

### 1. Implement Proper Language Construct Formatting
**Priority: HIGH**
- **Current State**: Most node types still have stub methods that preserve original text
- **Done**: expression statements, assignments (`=`), augmented assignments (`+=`, `*=`, etc.), while loops, if/elif/else, for loops, match statements, const declarations, unary operators, await expressions, enums, dictionaries, comments, break/continue/breakpoint, null literal, `is not` operator, attribute_subscript, subscript_arguments
- **Goal**: Replace remaining stubs with proper formatting implementations for:
  - **Literals**: strings, numbers, booleans (spacing and formatting)
  - **Operators**: comparisons (consistent spacing)
  - **Lambda expressions**: proper multiline formatting
  - **Match pattern interiors**: expressions inside match patterns (e.g. `Vector3(1,1+1,1)`, `[1,1,1]`) use `writeTrimmed` and don't get operator spacing
- **Files**: `src/GdWriter.zig`, `src/enums.zig`

### 2. Basic User Experience (Remaining)
**Priority: HIGH**
- Support stdin/stdout workflows for editor integration
- **Files**: `src/main.zig`

## Medium Priority Improvements

### 3. Configuration System
**Priority: MEDIUM**
- CLI options for indent size/type, line length
- Configuration file support (.gdpretty.toml)
- Multiple formatting profiles (compact, expanded, etc.)
- **Files**: `src/Context.zig`, `src/main.zig`

### 4. Better File Handling
**Priority: MEDIUM**
- In-place editing with `--write` flag
- Directory recursion and glob patterns
- `--check` mode to verify formatting without output
- `--diff` mode to show changes without applying
- **Files**: `src/main.zig`

### 5. Robustness
**Priority: MEDIUM**
- Proper exit codes for different error conditions
- Memory usage optimization for large files
- Performance benchmarking and regression tests
- **Files**: `src/main.zig`, `build.zig`

## Long-term Enhancements

### 6. Development Integration
**Priority: LOW**
- Language Server Protocol support
- Editor plugin examples and documentation
- Git pre-commit hook integration guide
- **Files**: New files, documentation

### 7. Distribution
**Priority: LOW**
- Binary releases via GitHub Actions
- Package manager integration (Homebrew, etc.)
- Docker image for CI/CD pipelines
- **Files**: `.github/workflows/`, packaging files

## Implementation Notes

### Critical Issue Details

**Generic Node Handling Fix:**
The current `depthFirstWalk` function in `src/formatter.zig` has this pattern:
```zig
if (!handled and cursor.gotoFirstChild()) {
    try depthFirstWalk(cursor, writer, context);
    _ = cursor.gotoParent();
}
```
This recurses into children but never writes the unhandled node's text. Need to add:
```zig
if (!handled) {
    // Write original node text as fallback
    try writer.writeNodeText(cursor.currentNode());
}
```

**Error Handling Pattern:**
Replace patterns like:
```zig
const node = parent.child(i) orelse @panic("Expected node");
```
With:
```zig
const node = parent.child(i) orelse return error.MalformedAST;
```

### Test Coverage Needed
- Error condition testing for malformed input
- Configuration option testing
- CLI argument testing
- Performance regression tests
- Integration testing with real GDScript projects

### Architecture Improvements
- Extract common node traversal patterns into reusable functions
- Remove unused code in `src/statements.zig`
- Make debug output conditional via compile-time flags
- Consider plugin architecture for extensibility

## Priority Order for Implementation

1. **Implement proper formatting** - Improve stub methods to add proper formatting rules
2. **Configuration system** - Allow user customization
3. **File handling improvements** - Better workflow integration
4. **Long-term enhancements** - Advanced features and distribution

For completed items, see CHANGELOG.md
