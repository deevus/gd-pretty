# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

gd-pretty is a GDScript code formatter built in Zig that uses tree-sitter for parsing. It formats GDScript files (Godot's scripting language) to ensure consistent code style.

## Development Commands

### Build and Run
```bash
# Build the project
zig build

# Run the formatter on files
zig build run -- file1.gd file2.gd

# Run directly after building
./zig-out/bin/gd-pretty file1.gd file2.gd
```

### Testing
```bash
# Run all tests (unit tests + snapshot tests)
zig build test

# Run a single test by creating a new test file
# Create: tests/input-output-pairs/my-test.in.gd
# Run tests to generate: tests/input-output-pairs/my-test.out.gd
# Review and commit the .out.gd file if correct
```

### Code Quality
```bash
# Format Zig code
zig fmt src/**/*.zig

# Run linter (if zlint is installed via mise)
zlint src/**/*.zig
```

## Architecture Overview

### Core Components

1. **Entry Point** (`src/main.zig`)
   - CLI interface and argument parsing
   - Tree-sitter parser initialization
   - Memory management setup
   - Test runner mode when no arguments provided

2. **Formatter Core** (`src/formatter.zig`)
   - `depthFirstWalk`: Main traversal algorithm
   - Compile-time node type to handler mapping
   - Fallback to recursive traversal for unhandled nodes

3. **GdWriter** (`src/GdWriter.zig`)
   - Central formatting logic
   - Individual `write*` methods for each AST node type
   - Handles indentation, spacing, and newlines

4. **Tree-sitter Integration** (`lib/tree-sitter/`)
   - Zig bindings for tree-sitter C API
   - GDScript grammar integration

### Adding New Node Types

1. Add the node type to `src/enums.zig` in the `GdNodeType` enum
2. Implement a `writeNodeTypeName` method in `src/GdWriter.zig`
3. The formatter will automatically route the node to your handler via compile-time mapping

### Testing Strategy

- Snapshot tests in `tests/input-output-pairs/`
- Input files: `*.in.gd`
- Expected output: `*.out.gd`
- Tests automatically stage output files with git
- Review git diff to verify formatting changes

### Key Implementation Notes

- Uses arena allocator for efficient memory management
- Buffered output writer for performance
- Context object tracks indentation state immutably
- Extensive assertions to catch type mismatches early
- Node type routing happens at compile time for zero overhead

### Code Style Rules

- Remove debug print statements rather than commenting them out
- Avoid leaving empty blocks when removing code
- Functions in Zig should be `camelCase`
- Types in Zig should be `PascalCase`
- Constants in Zig should be `snake_case`

## Outstanding Work

Check `TODO.md` for a prioritized list of improvements needed for the formatter, including critical bugs that cause invalid output and missing language features.

## Development Practices

- Always keep TODO.md up-to-date
- REMOVE completed items from TODO.md and ENSURE they are added to CHANGELOG.md with the CURRENT DATE

## Quick Commands

- Get the current date using `date` command in AEST
```bash
# Get current date in AEST
date -d "TZ='Australia/Sydney' today"
```

## Development Guidelines

- Don't make "simple fixes" to work around issues that could use more consideration

## Commit Guidelines

- Run tests before every commit
- DO NOT co-author git commits

## Release Process

To create a new release:

1. **Update version** in `build.zig.zon` and `src/main.zig`
2. **Update CHANGELOG.md** with release notes
3. **Commit changes** and push to main
4. **Create and push git tag**:
   ```bash
   git tag v0.0.2
   git push origin v0.0.2
   ```
5. **GitHub Actions** will automatically:
   - Run tests and linting
   - Verify tag version matches `build.zig.zon`
   - Build binaries for all platforms (Linux, macOS, Windows)
   - Create GitHub release with artifacts

Tags must follow semver format: `v0.1.0`, `v1.2.3`, etc.
```

## Development Workflow

- Double check GitHub workflow changes using `act`
```

## Development Guidance

- DO NOT make claims about "production-ready"

```