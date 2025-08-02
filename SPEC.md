# SPEC.md - Maximum Width Formatting Specification

This document describes how gd-pretty handles maximum line width and line breaking for GDScript code.

## Overview

The formatter enforces a configurable maximum line width to improve code readability. When expressions or statements exceed this width, they are broken across multiple lines with appropriate indentation.

## Configuration

### Default Settings
- **Maximum width**: 100 characters
- **Indent type**: Spaces
- **Indent size**: 4 spaces
- **Continuation indent**: 4 additional spaces beyond current scope

### Future Configuration Options
```bash
# CLI flags (planned)
gd-pretty --max-width 120 file.gd
gd-pretty --indent-type tabs --indent-size 1 file.gd

# Configuration file (planned: .gdpretty.toml)
max_width = 120
indent_type = "spaces"  # or "tabs"
indent_size = 4
```

## Line Breaking Rules

### Binary Expressions

When a binary expression exceeds maximum width, break after binary operators:

**Before:**
```gdscript
var result = 1 + 2 + 3 + 4 + 5 + 6 + 7 + 8 + 9 + 10 + 11 + 12 + 13 + 14 + 15 + 16 + 17 + 18 + 19 + 20
```

**After:**
```gdscript
var result = 1 + 2 + 3 + 4 + 5 + 6 + 7 + 8 + 9 + 10 +
    11 + 12 + 13 + 14 + 15 + 16 + 17 + 18 + 19 + 20
```

### Operator Precedence

Break at the lowest precedence operators first:

**Priority order (lowest to highest precedence):**
1. `or`, `||`
2. `and`, `&&`
3. `==`, `!=`, `<`, `>`, `<=`, `>=`, `in`, `is`
4. `|` (bitwise OR)
5. `^` (bitwise XOR)
6. `&` (bitwise AND)
7. `<<`, `>>` (bit shifts)
8. `+`, `-` (addition/subtraction)
9. `*`, `/`, `%` (multiplication/division/modulo)
10. `**` (power)

**Example:**
```gdscript
# Break at 'or' first (lowest precedence)
var complex = (a + b * c) > threshold or (x - y) < minimum or flag_enabled
# Becomes:
var complex = (a + b * c) > threshold or
    (x - y) < minimum or
    flag_enabled

# Within each part, break at '+' before '*' if needed
var long_math = very_long_variable_name + another_long_name * third_long_name + fourth_name
# Becomes:
var long_math = very_long_variable_name +
    another_long_name * third_long_name + fourth_name
```

## Indentation Rules

### Continuation Lines
- **Binary expressions**: Indent continuation lines one level deeper than the statement
- **Nested expressions**: Maintain relative indentation

**Example:**
```gdscript
class MyClass:
    func calculate():
        var result = first_long_variable_name + second_long_variable_name +
            third_long_variable_name + fourth_long_variable_name
```

### Alignment Considerations
- Avoid hanging indents that create visual confusion
- Keep continuation indentation consistent within a statement
- Don't align with opening parentheses or operators (too fragile)

## Width Calculation

### Character Counting
- **Spaces**: Count as 1 character each
- **Tabs**: When used, count as moving to next multiple of tab width (8 characters)
- **Unicode characters**: Count as 1 character each
- **Line endings**: Not included in width calculation

### Measurement Points
Width is measured at these decision points:
- Before writing binary operators
- Before writing function call arguments
- Before writing array/dictionary elements

## Implementation Strategy

### Phase 1: Binary Expressions (Current Focus)
1. Implement width tracking in `GdWriter.zig`
2. Add line breaking logic to `writeBinaryExpression`
3. Handle basic `+`, `-`, `*`, `/` operators
4. Update test: `addition_n_subtraction_expressions.in.gd`

### Phase 2: Complex Expressions
1. Extend to all binary operators with precedence rules
2. Handle nested expressions correctly
3. Add parenthesized expression support

### Phase 3: Other Constructs
1. Function call arguments
2. Array and dictionary literals
3. Function parameter lists
4. Match statement patterns

## Edge Cases

### Indivisible Elements
Some elements cannot be broken and may exceed max width:
- Long string literals
- Long identifiers
- Long numeric literals
- Comments

**Handling**: Allow these to exceed max width rather than breaking them.

### Minimum Width
If max width is set too low (< 40 characters), the formatter should:
- Issue a warning
- Use 40 characters as minimum
- Still attempt to format reasonably

### Already Broken Lines
If input already has line breaks in expressions:
- Respect existing breaks if they're reasonable
- Only add breaks if the existing format still exceeds width
- Don't remove manual breaks unless they create poor formatting

## Testing Strategy

### Test Cases
1. **Exact width boundaries**: Lines that are exactly at the limit
2. **Slightly over**: Lines that exceed by 1-2 characters
3. **Significantly over**: Lines that need multiple breaks
4. **Already formatted**: Input that's already well-formatted
5. **Mixed operators**: Expressions with different precedence levels
6. **Nested contexts**: Long expressions inside classes, functions, conditionals

### Success Criteria
- No output line exceeds max width (except indivisible elements)
- Code remains syntactically valid
- Formatting is consistent and readable
- Performance remains acceptable for large files

## Future Enhancements

### Smart Breaking
- Break at natural boundaries (after commas, before operators)
- Consider semantic grouping in expressions
- Avoid breaking inside "logical units"

### Context-Aware Formatting
- Different max widths for different contexts (comments vs code)
- Preserve intentional formatting in certain cases
- Integration with comment formatting

### Performance Optimization
- Lazy width calculation
- Caching of width measurements
- Efficient string building for long lines