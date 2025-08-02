const std = @import("std");

var log_file: ?std.fs.File = null;
var log_writer: ?std.fs.File.Writer = null;
var allocator: std.mem.Allocator = undefined;

/// Custom log function for std.log
pub fn logFn(
    comptime level: std.log.Level,
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
}

/// Initialize logging system based on CLI options
pub fn init(log_file_path: ?[]const u8, alloc: std.mem.Allocator) !void {
    allocator = alloc;

    if (log_file_path) |path| {
        // Create or truncate the log file
        log_file = std.fs.cwd().createFile(path, .{}) catch |err| {
            const stderr = std.io.getStdErr().writer();
            try stderr.print("Warning: Could not create log file '{s}': {}\n", .{ path, err });
            try stderr.print("Debug logging will be disabled.\n", .{});
            return;
        };

        log_writer = log_file.?.writer();

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
