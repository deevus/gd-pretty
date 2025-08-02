var log_file: ?File = null;
var log_writer: ?*Writer = null;
var allocator: Allocator = undefined;

var log_buf: [256]u8 = undefined;

/// Custom log function for std.log
pub fn logFn(
    comptime level: LogLevel,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    // Only log if we have a writer (i.e., --log-file was provided)
    const writer = log_writer orelse return;

    // Format: [LEVEL] scope: message
    const level_txt = switch (level) {
        .debug => "DEBUG",
        .info => "INFO",
        .warn => "WARN",
        .err => "ERROR",
    };

    const scope_name = @tagName(scope);

    writer.print("[{s}] {s}: " ++ format ++ "\n", .{ level_txt, scope_name } ++ args) catch return;
    writer.flush() catch return;
}

/// Initialize logging system based on CLI options
pub fn init(log_file_path: ?[]const u8, alloc: Allocator) !void {
    allocator = alloc;

    if (log_file_path) |path| {
        // Create or truncate the log file
        log_file = std.fs.cwd().createFile(path, .{}) catch |err| {
            try printError("Warning: Could not create log file '{s}': {}\nDebug logging will be disabled.\n", .{ path, err });
            return;
        };

        var log_file_writer = log_file.?.writer(&log_buf);
        log_writer = &log_file_writer.interface;

        std.log.info("Debug logging initialized: {s}", .{path});
    }
    // If log_file_path is null, log_writer remains null and logging is disabled
}

/// Cleanup function
pub fn deinit() void {
    if (log_file) |file| {
        std.log.info("Debug logging session ended", .{});
        file.close();
        log_file = null;
        log_writer = null;
    }
}

pub fn printMessageAndExit(comptime fmt: []const u8, args: anytype) !noreturn {
    var stdout_file = std.fs.File.stdout();
    defer stdout_file.close();

    var buf: [128]u8 = undefined;
    var stdout_writer = stdout_file.writer(&buf);
    var w = &stdout_writer.interface;
    try w.print(fmt, args);
    try w.flush();

    std.process.exit(0);
}

pub fn printError(comptime fmt: []const u8, args: anytype) !void {
    var stderr_file = std.fs.File.stderr();
    defer stderr_file.close();

    var buf: [128]u8 = undefined;
    var stderr_writer = stderr_file.writer(&buf);
    var w = &stderr_writer.interface;
    try w.print(fmt, args);
    try w.flush();
}

pub fn printErrorAndExit(comptime fmt: []const u8, args: anytype) !noreturn {
    try printError(fmt, args);
    std.process.exit(1);
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const File = std.fs.File;
const Writer = std.Io.Writer;
const LogLevel = std.log.Level;
