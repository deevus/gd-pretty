# TODO.md

This file tracks improvements needed for the gd-pretty GDScript formatter.

## Critical Issues

### 1. Fix Generic Node Handling
**Priority: CRITICAL**
- **Issue**: Unhandled node types are completely omitted from output, breaking the code
- **Impact**: Control flow statements (if/for/while) disappear entirely from formatted output
- **Solution**: Need fallback mechanism in `formatter.zig:depthFirstWalk` to preserve original text for unhandled nodes
- **Files**: `src/formatter.zig`

### 2. Replace Panic-Driven Error Handling  
**Priority: CRITICAL**
- **Issue**: 48+ instances of `unreachable` and `@panic` throughout codebase
- **Impact**: Tool crashes on unexpected input instead of graceful error handling
- **Solution**: Return proper errors instead of crashing on unexpected input, add graceful degradation for malformed AST nodes
- **Files**: `src/GdWriter.zig`, `src/formatter.zig`, `src/main.zig`

## High Priority Features

### 3. Implement Missing Language Constructs
**Priority: HIGH**
- **Control flow**: if/elif/else, for loops, while loops, match statements
- **Literals**: strings, numbers, booleans, arrays, dictionaries  
- **Operators**: binary operators, comparisons, assignments
- **Comments**: proper preservation and formatting
- **Files**: `src/GdWriter.zig`, `src/enums.zig`

### 4. Basic User Experience
**Priority: HIGH**
- Add `--help` and `--version` flags
- Remove debug noise with `--quiet` mode  
- User-friendly error messages instead of stack traces
- Support stdin/stdout workflows for editor integration
- **Files**: `src/main.zig`

## Medium Priority Improvements

### 5. Configuration System
**Priority: MEDIUM**
- CLI options for indent size/type, line length
- Configuration file support (.gdpretty.toml)
- Multiple formatting profiles (compact, expanded, etc.)
- **Files**: `src/Context.zig`, `src/main.zig`

### 6. Better File Handling
**Priority: MEDIUM**  
- In-place editing with `--write` flag
- Directory recursion and glob patterns
- `--check` mode to verify formatting without output
- `--diff` mode to show changes without applying
- **Files**: `src/main.zig`

### 7. Robustness
**Priority: MEDIUM**
- Proper exit codes for different error conditions
- Memory usage optimization for large files
- Performance benchmarking and regression tests
- **Files**: `src/main.zig`, `build.zig`

## Long-term Enhancements

### 8. Development Integration
**Priority: LOW**
- Language Server Protocol support
- Editor plugin examples and documentation
- Git pre-commit hook integration guide
- **Files**: New files, documentation

### 9. Distribution
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

1. **Fix generic node handling** - Without this, formatter produces invalid code
2. **Basic error handling** - Replace panics with proper error returns  
3. **CLI help system** - Make tool discoverable and usable
4. **Implement missing language constructs** - Add dedicated handlers for common node types
5. **Configuration system** - Allow user customization
6. **File handling improvements** - Better workflow integration
7. **Long-term enhancements** - Advanced features and distribution