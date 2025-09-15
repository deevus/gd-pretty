# Ticket: Comprehensive Comment Testing

## Epic
Comment-Aware Processing

## Summary
Create comprehensive test coverage for all comment scenarios and edge cases to ensure the comment-aware processing implementation is robust and reliable.

## Description
Develop a complete test suite that validates comment handling across all supported scenarios, including edge cases, integration scenarios, and regression testing for existing functionality.

## Acceptance Criteria

### 1. Snapshot Test Creation
- [ ] Create comprehensive `.in.gd` test files covering all comment scenarios
- [ ] Generate corresponding `.out.gd` expected output files
- [ ] Ensure tests cover the scenarios defined in ADR-002
- [ ] Validate that existing tests continue to pass (regression testing)

### 2. Core Comment Scenarios
- [ ] Inline comments after class declarations: `class X: # comment`
- [ ] Inline comments after function declarations: `func foo(): # comment`
- [ ] Standalone comments between class members
- [ ] Standalone comments between function statements
- [ ] Comments at the beginning of bodies
- [ ] Comments at the end of bodies

### 3. Edge Cases and Complex Scenarios
- [ ] Multiple consecutive comments
- [ ] Empty comment content: `#`
- [ ] Comments with special characters and content
- [ ] Mixed inline and standalone comments
- [ ] Deeply nested structures with comments at each level
- [ ] Very long comments that might affect line width considerations

### 4. Integration Testing
- [ ] Comments in classes containing multiple functions
- [ ] Comments in functions with complex statement blocks
- [ ] Comments in nested class structures
- [ ] Comments with various indentation levels
- [ ] Comments combined with existing complex formatting scenarios

### 5. Performance Testing
- [ ] Large files with many comments (performance validation)
- [ ] Files with high comment-to-code ratios
- [ ] Verify no significant performance regression

## Implementation Notes

### Test File Structure
Create test files following the existing pattern:
```
tests/input-output-pairs/
├── comments_inline_after_declarations.in.gd
├── comments_standalone_between_statements.in.gd
├── comments_multiple_consecutive.in.gd
├── comments_mixed_inline_standalone.in.gd
├── comments_nested_structures.in.gd
├── comments_edge_cases.in.gd
└── comments_performance_large.in.gd
```

### Example Test Content

#### comments_inline_after_declarations.in.gd
```gd
class SimpleClass: # Simple inline comment
    func simple_method(): # Method comment
        pass

class ComplexClass: # Complex class comment
    func method_one(): # First method
        var x = 1

    func method_two(): # Second method
        var y = 2
```

#### comments_standalone_between_statements.in.gd
```gd
class TestClass:
    # Comment before first method
    func first():
        # Comment at start of method
        var a = 1
        # Comment between statements
        var b = 2
        # Comment at end of method

    # Comment between methods
    func second():
        pass

    # Comment at end of class
```

#### comments_multiple_consecutive.in.gd
```gd
class Example:
    # First comment
    # Second comment
    # Third comment
    func method():
        # Comment one
        # Comment two
        # Comment three
        pass
```

### Integration with Existing Tests
- [ ] Verify `inline_comments_on_compound_stmts.in.gd` passes
- [ ] Ensure all existing snapshot tests continue to pass
- [ ] Add comment variations to existing complex test scenarios

### Critical Output Quality Validation
Based on current formatting issues identified in `inline_comments_on_compound_stmts.out.gd`:

#### Current Formatting Problems to Address
The current output shows critical issues that must be resolved:
```gd
pass

class X:
 # aaa
        func foo():
 # bbb
                pass
```

**Must Fix:**
- [ ] **Inline comment positioning**: `class X: # aaa` should keep comment on same line
- [ ] **Proper indentation**: Comments must follow consistent indentation rules
- [ ] **Element association**: Comments should be visually associated with correct code elements
- [ ] **Spacing consistency**: Exact spacing requirements for inline comments

#### Required Output Format Standards
- [ ] **Inline comments**: `element: # comment` format with exactly one space before `#`
- [ ] **Standalone comments**: Indented to match context level of surrounding code
- [ ] **Consistent indentation**: 4 spaces per indentation level throughout
- [ ] **No formatting artifacts**: No extra whitespace, broken lines, or misaligned elements
- [ ] **Content preservation**: Original comment text unchanged

### Performance Validation
Create large test files to ensure:
- [ ] No significant slowdown in processing time
- [ ] Memory usage remains reasonable
- [ ] No stack overflow with deeply nested comments

## Files to Create/Modify
- `tests/input-output-pairs/comments_*.in.gd` - New test input files
- `tests/input-output-pairs/comments_*.out.gd` - Expected output files (generated)
- Update existing test files to include comment scenarios where appropriate

## Dependencies
- #001: Core Comment Infrastructure
- #002: Update writeClassDefinition
- #003: Update writeFunctionDefinition
- #004: Update writeBody for comments

## Related Tickets
- #006: Performance validation (overlaps with performance testing here)

## Test Execution Strategy

### 1. Incremental Testing
Run tests after each implementation ticket to catch issues early:
- After #001: Test basic comment handling in isolation
- After #002: Test class-level comment scenarios
- After #003: Test function-level comment scenarios
- After #004: Test comprehensive body comment scenarios

### 2. Regression Testing
- Run full existing test suite after each change
- Ensure no existing functionality is broken
- Validate that performance remains acceptable

### 3. Edge Case Validation
- Test with malformed comments (if any)
- Test with extremely long comments
- Test with comments containing special characters
- Test boundary conditions (empty files, files with only comments)

## Estimated Effort
Medium (1-2 days)

## Definition of Done
- [ ] All acceptance criteria met
- [ ] Comprehensive test coverage for all comment scenarios
- [ ] All new tests pass
- [ ] All existing tests continue to pass (no regressions)
- [ ] Performance validation completed
- [ ] Test files follow project conventions
- [ ] Documentation updated with new test scenarios
- [ ] Edge cases thoroughly tested

### Critical Quality Gates
- [ ] **Output format validation**: All test outputs match expected formatting standards exactly
- [ ] **Visual inspection requirement**: Manual review of all generated `.out.gd` files for quality
- [ ] **Formatting consistency**: No variations in indentation, spacing, or comment positioning
- [ ] **Content integrity**: All comment content preserved without modification across all tests

### Specific Quality Validation Requirements
- [ ] **Inline comment formatting**: All `element: # comment` patterns correctly formatted
- [ ] **Standalone comment indentation**: All standalone comments properly indented for context
- [ ] **No formatting artifacts**: Zero instances of extra whitespace, broken alignment, or structural issues
- [ ] **Regression prevention**: All existing non-comment formatting preserved perfectly

### Testing Infrastructure Quality
- [ ] **Test file organization**: Clear naming and organization of test scenarios
- [ ] **Comprehensive coverage**: Every combination of comment types and positions tested
- [ ] **Edge case robustness**: Extreme scenarios (empty comments, very long comments, special characters) handled
- [ ] **Integration validation**: Comments work correctly with all GDScript language constructs