# PLAN.md - Phase 1 Implementation Plan (Revised)

## Overview

This document outlines the revised implementation plan for Phase 1 of maximum width formatting: **Binary Expression Line Breaking using Error-Driven Approach**. We leverage Zig's standard library `CountingWriter` and error handling to implement line wrapping for long binary expressions.

## Architectural Approach

Instead of complex pre-analysis, we use an **optimistic execution with graceful fallback** strategy:

1. **Try to write normally** - Attempt single-line formatting
2. **Detect overflow** - Use `MaxWidthExceeded` error when line gets too long
3. **Fallback gracefully** - Switch to multiline formatting when needed
4. **Use stdlib tools** - Leverage `std.io.countingWriter()` for tracking

## Target Test Case

**File**: `tests/input-output-pairs/addition_n_subtraction_expressions.in.gd`

**Current Input/Output** (identical):
```gdscript
class X:
	func foo():
		var x = 1 + 1
		var y = 1 - 1
		var q = 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1
		var w = 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1
```

**Target Output**:
```gdscript
class X:
    func foo():
        var x = 1 + 1
        var y = 1 - 1
        var q = 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 +
            1 + 1 + 1
        var w = 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 - 1 -
            1 - 1 - 1
```

## Implementation Steps

### Step 1: Add Configuration Support

**Files to modify**: `src/Context.zig`

**Changes needed**:
```zig
const Context = @This();

indent_level: u32 = 0,
indent_str: []const u8 = "    ",
indent_size: u32 = 4,
indent_type: IndentType = .spaces,
max_width: u32 = 100,  // ← Add this line

pub fn indent(self: Context) Context {
    return .{
        .indent_level = self.indent_level + 1,
        .indent_str = self.indent_str,
        .indent_size = self.indent_size,
        .indent_type = self.indent_type,
        .max_width = self.max_width,  // ← Add this line
    };
}

pub fn deindent(self: Context) Context {
    return .{
        .indent_level = @max(0, self.indent_level - 1),
        .indent_str = self.indent_str,
        .indent_size = self.indent_size,
        .indent_type = self.indent_type,
        .max_width = self.max_width,  // ← Add this line
    };
}
```

**Tasks**:
- [x] ~~Add max_width field with default 100~~ (COMPLETED)
- [x] ~~Update `indent()` and `deindent()` methods to include max_width~~ (COMPLETED)
- [x] ~~Add indent_type enum and field~~ (Already implemented)
- [x] ~~Add indent_size field with default 4~~ (Already implemented) 
- [x] ~~Update Context creation to use new defaults~~ (Already implemented)

**Current Status**: COMPLETED ✅

### Step 2: Add Error Type and CountingWriter Integration

**Files to modify**: `src/GdWriter.zig`

**Current Focus**: Implementing CountingWriter with newline detection and debug output

**Changes needed**:
```zig
const std = @import("std");

// Add error type
const WriteError = error{
    MaxWidthExceeded,
    OutOfMemory,
    // Include existing writer errors
} || @TypeOf(writer).Error;

// Modify GdWriter struct
const GdWriter = struct {
    counting_writer: std.io.CountingWriter(@TypeOf(underlying_writer)),
    current_line_start: u64 = 0,
    allocator: std.mem.Allocator,
    
    // Helper methods
    fn getCurrentLineWidth(self: *Self) u32 {
        return @intCast(u32, self.counting_writer.bytes_written - self.current_line_start);
    }
    
    fn writeWithCheck(self: *Self, text: []const u8, context: Context) WriteError!void {
        if (self.getCurrentLineWidth() + text.len > context.max_width) {
            return WriteError.MaxWidthExceeded;
        }
        
        try self.counting_writer.write(text);
        
        // Reset line start on newlines
        if (std.mem.lastIndexOf(u8, text, "\n")) |_| {
            self.current_line_start = self.counting_writer.bytes_written;
        }
    }
};
```

**Tasks**:
- [ ] Add WriteError type with MaxWidthExceeded (DEFERRED)
- [x] ~~Replace direct writer with std.io.CountingWriter wrapper~~ (COMPLETED)
- [x] ~~Add current_line_start tracking field~~ (COMPLETED) 
- [x] ~~Implement getCurrentLineWidth() helper~~ (COMPLETED)
- [x] ~~Add newline detection with debug output for line lengths~~ (COMPLETED)
- [x] ~~Update initialization to use countingWriter()~~ (COMPLETED)
- [x] ~~Replace all .out.writeAll() calls with new .write() method~~ (COMPLETED)
- [x] ~~**Fix compilation errors:**~~ (COMPLETED)
  - [x] ~~Fix writer.write() return value handling (must discard with _)~~ (COMPLETED)
  - [x] ~~Fix type mismatch with formatter.depthFirstWalk()~~ (COMPLETED)
  - [x] ~~Fix splitScalar usage~~ (COMPLETED)

**Current Status**: COMPLETED ✅

### Step 3: Implement Error-Driven Binary Expression Writing

**Files to modify**: `src/GdWriter.zig`

**Current Focus**: Implementing MaxWidthExceeded error type and binary expression handling

**Changes needed**:
```zig
fn writeBinaryExpression(self: *Self, node: *const Node, context: Context) !void {
    // Try normal (single-line) writing first
    self.writeBinaryExpressionNormal(node, context) catch |err| switch (err) {
        WriteError.MaxWidthExceeded => {
            // Fallback to multiline writing
            return self.writeBinaryExpressionMultiline(node, context);
        },
        else => return err,
    };
}

fn writeBinaryExpressionNormal(self: *Self, node: *const Node, context: Context) WriteError!void {
    try self.writeChild(node.left_operand, context);
    try self.writeWithCheck(" + ", context);  // May throw MaxWidthExceeded
    try self.writeChild(node.right_operand, context);
}

fn writeBinaryExpressionMultiline(self: *Self, node: *const Node, context: Context) !void {
    try self.writeChild(node.left_operand, context);
    try self.counting_writer.write(" +");  // Operator without trailing space
    try self.writeNewline();
    try self.writeIndent(context.indent());
    try self.writeChild(node.right_operand, context);
}
```

**Tasks**:
- [ ] Add WriteError type with MaxWidthExceeded
- [ ] Implement writeBinaryExpression() with error handling
- [ ] Implement writeBinaryExpressionNormal() for single-line attempt
- [ ] Implement writeBinaryExpressionMultiline() for fallback
- [ ] Handle operator spacing consistently
- [ ] Support all basic operators (`+`, `-`, `*`, `/`, `%`)

### Step 4: Handle Backtracking Strategy

**Files to modify**: `src/GdWriter.zig`

**Approach**: Use temporary buffer to avoid corrupting output on MaxWidthExceeded

```zig
fn writeBinaryExpressionWithBacktrack(self: *Self, node: *const Node, context: Context) !void {
    // Create temporary buffer
    var temp_buffer = std.ArrayList(u8).init(self.allocator);
    defer temp_buffer.deinit();
    
    // Create temporary counting writer
    var temp_counting_writer = std.io.countingWriter(temp_buffer.writer());
    var temp_line_start: u64 = 0;
    
    // Try writing to temporary buffer
    const success = blk: {
        // Simulate writing with width checking
        // ... implementation details
        break :blk true; // or false if MaxWidthExceeded
    };
    
    if (success) {
        // Write buffer contents to real output
        try self.counting_writer.writeAll(temp_buffer.items);
    } else {
        // Use multiline approach directly
        try self.writeBinaryExpressionMultiline(node, context);
    }
}
```

**Tasks**:
- [ ] Implement temporary buffer strategy for backtracking
- [ ] Handle memory management for temporary allocations
- [ ] Ensure line width tracking stays consistent
- [ ] Add proper error propagation

### Step 5: Update Node Type Routing

**Files to modify**: `src/GdWriter.zig`

**Current method**: `writeBinaryExpression()` (stub)

**Changes needed**:
- [ ] Replace stub implementation with new error-driven approach
- [ ] Ensure compatibility with existing node traversal
- [ ] Handle all binary operator types from `enums.zig`
- [ ] Maintain backward compatibility for expressions that fit on one line

### Step 6: Add Proper Newline and Indentation Helpers

**Files to modify**: `src/GdWriter.zig`

**New/updated methods**:
```zig
fn writeNewline(self: *Self) !void {
    try self.counting_writer.write("\n");
    self.current_line_start = self.counting_writer.bytes_written;
}

fn writeIndent(self: *Self, context: Context) !void {
    for (0..context.indent_level) |_| {
        try self.counting_writer.write(context.indent_str);
    }
}

fn writeContinuationIndent(self: *Self, context: Context) !void {
    // Write current indent level + one more level for continuation
    try self.writeIndent(context.indent());
}
```

**Tasks**:
- [ ] Implement writeNewline() with line tracking reset
- [ ] Leverage existing Context.indent() infrastructure
- [ ] Implement writeContinuationIndent() for broken lines
- [x] ~~Implement basic indentation~~ (Context already handles this)

### Step 7: Testing and Validation

**Tasks**:
- [ ] Run existing tests to ensure no regressions
- [ ] Manually update target test output file with expected formatting
- [ ] Run target test to verify it passes
- [ ] Test edge cases:
  - [ ] Expressions exactly at max width
  - [ ] Very short expressions (shouldn't break)
  - [ ] Mixed operators (`1 + 2 * 3 - 4`)
  - [ ] Deeply nested expressions
  - [ ] Error conditions (allocation failures)

### Step 8: Error Handling and Edge Cases

**Tasks**:
- [ ] Handle allocation failures gracefully
- [ ] Ensure no infinite loops in error handling
- [ ] Test with very small max_width values (< 20)
- [ ] Verify all binary operators work correctly
- [ ] Add bounds checking for line width calculations

## File Structure Changes

```
src/
├── Context.zig          # Modified: Add max_width field
├── GdWriter.zig         # Modified: Add CountingWriter integration and error handling
├── enums.zig           # No changes needed
├── formatter.zig       # No changes needed  
└── main.zig            # No changes needed

docs/
└── adrs/
    └── 001-error-driven-line-breaking.md  # New: ADR documenting approach
```

## Architecture Benefits

### **Advantages of Error-Driven Approach**:
1. **Simplicity**: No complex pre-analysis required
2. **Composability**: Works for any construct (arrays, function calls, etc.)
3. **Performance**: Only does work when needed
4. **Maintainability**: Clear separation of concerns
5. **Stdlib Integration**: Leverages proven Zig standard library

### **Comparison to Pre-Analysis Approach**:
- **Less Code**: ~60% fewer lines of implementation
- **Better Performance**: No upfront measurement overhead
- **More Flexible**: Easy to extend to new language constructs
- **Simpler Testing**: Fewer edge cases and code paths

## Testing Strategy

### Unit Tests
1. **CountingWriter integration**: Test byte counting and line tracking
2. **Error propagation**: Test MaxWidthExceeded handling
3. **Backtracking**: Test temporary buffer approach

### Integration Tests  
1. **Target test case**: `addition_n_subtraction_expressions.in.gd`
2. **Regression tests**: Ensure other tests still pass
3. **Edge cases**: Boundary conditions and error scenarios

## Success Criteria

- [ ] Long addition/subtraction expressions are broken across lines
- [ ] No line exceeds 100 characters (except indivisible elements)
- [ ] Continuation lines are properly indented (+4 spaces)
- [ ] Short expressions remain on single lines
- [ ] All existing tests continue to pass
- [ ] Code remains syntactically valid GDScript
- [ ] No performance regression on existing functionality

## Risk Mitigation

### Potential Issues:
1. **Memory overhead**: Temporary buffers for backtracking
2. **Error handling complexity**: Managing MaxWidthExceeded propagation
3. **Line tracking accuracy**: Ensuring byte counts stay accurate
4. **Performance impact**: CountingWriter overhead

### Mitigation Strategies:
1. Use arena allocator for temporary buffers, clean up after each expression
2. Keep error handling local to individual write operations
3. Add comprehensive tests for line width calculation edge cases
4. Profile CountingWriter performance impact and optimize if needed

## Timeline Estimate

- **Step 1**: Configuration ~~(30 minutes)~~ ✅ COMPLETED
- **Step 2**: CountingWriter integration ~~(1-2 hours)~~ 🚫 BLOCKED - needs compilation fixes
- **Step 3**: Error-driven binary expression writing (2-3 hours) - PENDING  
- **Step 4**: Backtracking strategy (1-2 hours) - PENDING
- **Step 5-6**: Integration and helpers (1 hour) - PENDING
- **Step 7-8**: Testing and edge cases (2-3 hours) - PENDING

**Current Progress**: Step 1 complete, Step 2 COMPLETED ✅
**Next Action**: Implement Step 3 (Error-driven binary expression writing)
**Total**: 7-11 hours of development time *(significantly reduced from original 9-13 hours)*

**Time Spent**: ~2 hours on Steps 1-2 (Configuration + CountingWriter integration)

## Immediate Next Steps

**COMPLETED - Step 2 CountingWriter Integration:**
1. ✅ Fixed `counting_writer.write()` return value - used `writeAll()` instead
2. ✅ Fixed type mismatch with `formatter.depthFirstWalk()` - added `.any()` for proper AnyWriter type
3. ✅ Tested CountingWriter integration with debug output - successfully tracks line lengths

**Verification Results:**
1. ✅ Project builds successfully without compilation errors
2. ✅ All tests run without regressions
3. ✅ Line length tracking confirmed working (debug output shows accurate character counts)
4. ✅ Long lines detected (99+ characters) near max_width threshold of 100

**Ready for Step 3:**
1. Add MaxWidthExceeded error type to enable error-driven approach
2. Implement binary expression error handling and fallback formatting
3. Test with addition/subtraction expressions file

## Next Steps After Phase 1

Once Phase 1 is complete and working:
1. Extend error-driven approach to function calls and other constructs
2. Add more sophisticated operator precedence handling
3. Implement CLI configuration options for max_width
4. Add array/dictionary literal line breaking