# ADR-001: Error-Driven Line Breaking Architecture

## Status

Accepted

## Context

The gd-pretty GDScript formatter needs to implement maximum line width enforcement to improve code readability. When expressions or statements exceed a configurable maximum width, they should be broken across multiple lines with appropriate indentation.

We evaluated two main architectural approaches:

### Approach 1: Pre-Analysis Strategy
- Analyze expressions upfront to calculate total width
- Pre-determine break points based on operator precedence
- Choose single-line vs multiline formatting before writing
- Requires complex measurement and break-point detection logic

### Approach 2: Error-Driven Strategy
- Attempt normal (single-line) writing first
- Use error handling to detect when maximum width is exceeded
- Gracefully fallback to multiline formatting when needed
- Leverage Zig's standard library `CountingWriter` for tracking

## Decision

We chose the **Error-Driven Strategy** using `std.io.CountingWriter` and custom error handling.

## Architecture

### Core Components

```zig
// Extend existing error type
pub const Error = error{
    MalformedAST,
    UnexpectedNodeType,
    MissingRequiredChild,
    InvalidNodeStructure,
    MaxWidthExceeded,  // New error for line width enforcement
} || std.io.AnyWriter.Error;

// Writer with default width checking
const GdWriter = struct {
    counting_writer: std.io.CountingWriter(@TypeOf(underlying_writer)),
    current_line_start: u64 = 0,

    // Default write method checks width
    fn write(self: *Self, text: []const u8) Error!void {
        if (self.getCurrentLineWidth() + text.len > self.context.max_width) {
            return Error.MaxWidthExceeded;
        }
        // ... normal write logic
    }

    // Bypass width checking for indivisible elements
    fn writeUnchecked(self: *Self, text: []const u8) !void {
        // Direct write without width checking
        try self.counting_writer.writer().writeAll(text);
    }
};
```

### Execution Flow

1. **Optimistic Writing**: Try to write expressions on single lines using default `write()` method
2. **Error Detection**: `write()` throws `MaxWidthExceeded` when line gets too long
3. **Graceful Fallback**: Catch error and switch to multiline formatting
4. **Direct Multiline Writing**: No backtracking needed - write multiline format directly

### Example Usage

```zig
fn writeBinaryExpression(self: *Self, node: *const Node, context: Context) !void {
    self.writeBinaryExpressionNormal(node, context) catch |err| switch (err) {
        WriteError.MaxWidthExceeded => {
            return self.writeBinaryExpressionMultiline(node, context);
        },
        else => return err,
    };
}
```

## Rationale

### Why Error-Driven Over Pre-Analysis

1. **Simplicity**: ~60% less implementation code
   - No complex expression measurement logic
   - No break-point analysis algorithms
   - Simple try/fallback pattern

2. **Performance**: Only does work when needed
   - Zero overhead for expressions that fit on one line
   - No upfront measurement of every expression
   - `CountingWriter` is lightweight

3. **Composability**: Works for any language construct
   - Binary expressions, function calls, arrays, etc.
   - Single mechanism handles all line-breaking scenarios
   - Easy to extend to new GDScript features

4. **Maintainability**: Clear separation of concerns
   - Normal formatting logic is independent
   - Multiline formatting is independent
   - Error handling bridges them cleanly

5. **Stdlib Integration**: Leverages proven Zig tools
   - `std.io.CountingWriter` handles byte tracking
   - No custom width calculation bugs
   - Zero additional dependencies

### Why CountingWriter Over Custom Tracking

1. **Proven Implementation**: Standard library is battle-tested
2. **Performance**: Optimized by Zig team
3. **Correctness**: No bugs in byte counting logic
4. **Maintenance**: Updates come with Zig upgrades

## Implementation Strategy

### Direct Error-Driven Approach

No backtracking or temporary buffers needed. When `MaxWidthExceeded` occurs, we simply switch to multiline formatting:

```zig
fn writeBinaryExpression(self: *Self, node: *const Node, context: Context) !void {
    // Try single-line format first
    self.writeBinaryExpressionNormal(node, context) catch |err| switch (err) {
        Error.MaxWidthExceeded => {
            // Switch to multiline format
            return self.writeBinaryExpressionMultiline(node, context);
        },
        else => return err,
    };
}
```

### Line Width Tracking

```zig
fn getCurrentLineWidth(self: *Self) u32 {
    return @intCast(u32, self.counting_writer.bytes_written - self.current_line_start);
}

// Reset on newlines
if (std.mem.lastIndexOf(u8, text, "\n")) |_| {
    self.current_line_start = self.counting_writer.bytes_written;
}
```

## Consequences

### Positive

- **Reduced Complexity**: Simpler codebase to maintain
- **Better Performance**: No wasted computation on expressions that fit
- **Extensibility**: Easy to add line breaking to other constructs
- **Reliability**: Uses proven stdlib components
- **Development Speed**: Faster to implement and test

### Negative

- **Error Handling Complexity**: Need to manage MaxWidthExceeded propagation
- **Non-Traditional**: Less common pattern than upfront analysis
- **Partial Output**: Must ensure no partial output when switching to multiline

### Neutral

- **Learning Curve**: Team needs to understand error-driven approach
- **Testing Strategy**: Different edge cases than pre-analysis approach

## Alternatives Considered

### 1. Pre-Analysis with Break Points
```zig
const analysis = analyzeBinaryExpression(node);
if (analysis.total_width > max_width) {
    writeWithBreaks(node, analysis.break_points);
} else {
    writeNormal(node);
}
```

**Rejected because**: Complex to implement, poor performance, hard to extend

### 2. Streaming with Look-Ahead
```zig
while (hasMoreTokens()) {
    const next_token = peekToken();
    if (current_width + next_token.width > max_width) {
        writeNewline();
    }
    writeToken(consumeToken());
}
```

**Rejected because**: Requires tokenization, breaks abstraction boundaries

### 3. Two-Pass Rendering
```zig
// Pass 1: Measure
const width = measureExpression(node);
// Pass 2: Format
if (width > max_width) {
    writeMultiline(node);
} else {
    writeNormal(node);
}
```

**Rejected because**: Duplicate traversal overhead, complexity

## References

- [Zig Standard Library - CountingWriter](https://ziglang.org/documentation/master/std/#A;std:io.CountingWriter)
- [Error Handling in Zig](https://ziglang.org/documentation/master/#Errors)
- [SPEC.md - Maximum Width Formatting Specification](../SPEC.md)
- [PLAN.md - Phase 1 Implementation Plan](../../PLAN.md)

## Revision History

- **2024-12-XX**: Initial decision record created
- **Status**: Accepted for implementation in Phase 1
