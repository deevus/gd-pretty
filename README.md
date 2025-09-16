# gd-pretty

An experimental GDScript code formatter built in Zig using tree-sitter for parsing.

⚠️ **Alpha Software**: This formatter is in early development and may produce incorrect output or crash. Use with caution and always backup your code.

## Current Status

This is alpha software with limited functionality:

- **Basic formatting** works for simple GDScript files
- **Many language features** are not yet supported
- **Output may be incorrect** - always review changes
- **Breaking changes** expected between versions
- **Not recommended** for production use

## Installation

### From Release

Download the latest binary from the [releases page](https://github.com/deevus/gd-pretty/releases).

### Build from Source

Requirements:
- [Zig 0.14.1+](https://ziglang.org/download/)

```bash
git clone https://github.com/deevus/gd-pretty.git
cd gd-pretty
zig build
./zig-out/bin/gd-pretty --help
```

## Usage

⚠️ **Always backup your files before running the formatter**

### Command Line

```bash
# Format a single file (BACKUP FIRST!)
gd-pretty script.gd

# Format multiple files (BACKUP FIRST!)
gd-pretty player.gd enemy.gd ui/*.gd

# Show help
gd-pretty --help

# Show version
gd-pretty --version
```



## Language Support Status

Many GDScript features are not yet implemented:

- 🚧 **Classes & Inheritance**: Partial support
- 🚧 **Functions**: Basic support, missing advanced features
- 🚧 **Variables**: Basic support
- 🚧 **Control Flow**: While loops fully supported, if/for/match statements partial
- 🚧 **Data Types**: Partial support
- 🚧 **Operators**: Basic support
- ❌ **Advanced Features**: Signals, properties, annotations, lambdas mostly unsupported
- 🚧 **Comments**: Basic preservation

See [TODO.md](TODO.md) for a detailed list of missing features and known issues.

## Known Issues

- May produce invalid GDScript output
- Many language constructs not yet supported
- Limited error handling
- Performance not optimized
- Test coverage incomplete

## Development



### Quick Start

```bash
# Build and test
zig build
zig build test

# Format Zig code
zig fmt src/**/*.zig
```

### Architecture

- **Parser**: tree-sitter with GDScript grammar
- **Formatter**: Depth-first AST traversal with dedicated node handlers
- **Output**: Buffered writing with indentation management
- **Testing**: Snapshot testing with input/output file pairs

## Contributing

This project needs help! Areas where contributions are especially welcome:

1. Implementing missing GDScript language features
2. Adding test cases
3. Fixing formatting bugs
4. Improving error handling

Please:
1. Fork the repository
2. Create a feature branch
3. Add tests for your changes
4. Run `zig build test` to ensure all tests pass
5. Submit a pull request

## License

MIT License. See [LICENSE](LICENSE) for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history and detailed changes.

## Related Projects

- [tree-sitter-gdscript](https://github.com/PrestonKnopp/tree-sitter-gdscript) - GDScript grammar for tree-sitter
- [Godot](https://godotengine.org/) - Game engine that uses GDScript
