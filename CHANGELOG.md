# CHANGELOG.md

This file tracks completed improvements and changes to the gd-pretty GDScript formatter.

## [Unreleased] - July 24, 2025

### Added
- **CLI Interface**: Added zig-cli integration with proper help, version flags, and positional argument handling
  - `--help` and `-h` flags show comprehensive usage information
  - `--version` and `-v` flags display version information
  - Positional argument support for file paths
  - Professional CLI appearance with colored output support
- **Error Handling**: User-friendly error messages instead of raw stack traces
  - File not found errors now show clear messages
  - Grammar loading failures are handled gracefully
  - Proper exit codes for different error conditions

### Fixed
- **Debug Output**: Removed debug noise that was cluttering formatter output
  - Eliminated "Node type: ..." debug prints from console
  - Clean formatted code output without debug information
  - Tool is now usable in production workflows

### Improved
- **User Experience**: Tool is now discoverable and professional
  - No more crashes on missing files or invalid arguments
  - Clear usage instructions and examples in help text
  - Proper error messages guide users to solutions

## Version History

### [0.1.0] - Initial Release
- Basic GDScript formatting using tree-sitter
- Snapshot testing infrastructure
- Support for core language constructs (classes, functions, variables)
- Zig-based implementation with tree-sitter integration