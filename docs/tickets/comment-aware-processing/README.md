# Comment-Aware Processing Epic

## Overview
This epic implements comment-aware node processing for the gd-pretty GDScript formatter, addressing the critical issue where the formatter crashes when comments appear between expected structural AST nodes.

## Background
The current formatter assumes a rigid AST structure and crashes on valid GDScript code like:
```gd
class X: # inline comment
    func foo(): # another comment
        pass
```

This epic implements the architecture defined in [ADR-002: Comment-Aware Node Processing](../../adrs/002-comment-aware-node-processing.md), using a runtime "skip-and-process" approach inspired by Zig fmt.

## Epic Goals
1. **Eliminate crashes** when comments appear in valid positions
2. **Preserve comment formatting** and placement
3. **Maintain existing functionality** for non-comment scenarios
4. **Ensure acceptable performance** with the new processing approach

## Ticket Dependencies

```
001 Core Infrastructure
    ↓
002 writeClassDefinition ←─┐
    ↓                      │
003 writeFunctionDefinition │
    ↓                      │
004 writeBody              │
    ↓                      │
005 Comprehensive Testing ←┘
    ↓
006 Performance Validation
```

## Tickets

### Phase 1: Core Infrastructure
- **[#001: Core Comment Infrastructure](001-core-comment-infrastructure.md)**
  - Foundation: `handleComment()` method and classification utilities
  - Error handling improvements for unknown node types
  - **Effort**: Medium (1-2 days)
  - **Status**: Not Started

### Phase 2: Structural Method Updates
- **[#002: Update writeClassDefinition](002-update-writeClassDefinition.md)**
  - Handle comments between `:` and class body
  - **Effort**: Small (0.5-1 day)
  - **Status**: Not Started
  - **Depends on**: #001

- **[#003: Update writeFunctionDefinition](003-update-writeFunctionDefinition.md)**
  - Handle comments between function signature and body
  - **Effort**: Small (0.5-1 day)
  - **Status**: Not Started
  - **Depends on**: #001, #002

- **[#004: Update writeBody](004-update-writeBody-comments.md)**
  - Handle comments between statements in bodies
  - **Effort**: Small to Medium (1 day)
  - **Status**: Not Started
  - **Depends on**: #001, #002, #003

### Phase 3: Validation and Optimization
- **[#005: Comprehensive Testing](005-comprehensive-testing.md)**
  - Complete test coverage for all comment scenarios
  - **Effort**: Medium (1-2 days)
  - **Status**: Not Started
  - **Depends on**: #001, #002, #003, #004

- **[#006: Performance Validation](006-performance-validation.md)**
  - Performance testing and optimization
  - **Effort**: Medium (1-2 days)
  - **Status**: Not Started
  - **Depends on**: #001-#005

## Total Estimated Effort
**6-9 days** across all tickets

## Success Criteria
1. **Functionality**: All test cases from ADR-002 pass
2. **Robustness**: No crashes on valid GDScript with comments
3. **Performance**: <10% overhead compared to baseline
4. **Quality**: All existing tests continue to pass

## Key Test Cases
The implementation must handle:
```gd
// Inline comments after structural elements
class X: # comment
    pass

func foo(): # comment
    pass

// Comments between statements
class Y:
    # standalone comment
    func bar():
        pass
    # another comment
    func baz():
        pass

// Multiple consecutive comments
class Z:
    # comment 1
    # comment 2
    # comment 3
    func qux():
        pass

// Mixed inline and standalone
class W: # inline
    # standalone
    func method(): # inline
        # standalone
        pass
```

## Architecture Summary
The implementation uses a **runtime skip-and-process pattern**:

1. **Iterate** through child nodes instead of direct indexing
2. **Handle comments** when encountered using `handleComment()`
3. **Find structural nodes** (like `body`) after processing comments
4. **Maintain** existing formatting behavior for non-comment scenarios

This approach provides robustness without the complexity of preprocessing comment extraction and association.

## References
- [ADR-002: Comment-Aware Node Processing](../../adrs/002-comment-aware-node-processing.md)
- [Failing test case: inline_comments_on_compound_stmts.in.gd](../../../tests/input-output-pairs/inline_comments_on_compound_stmts.in.gd)
- [Ruff Formatter Comment Handling](https://github.com/astral-sh/ruff/tree/main/crates/ruff_python_formatter/src/comments)
- [Zig AST Renderer](https://github.com/ziglang/zig/blob/master/lib/std/zig/Ast/Render.zig)