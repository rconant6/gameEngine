const Engine = @import("engine.zig").Engine;
const debug = @import("debug");
const ErrorEntry = debug.ErrorEntry;
const Subsystem = debug.SubSystem;

pub fn logDebug(
    self: *Engine,
    subsystem: Subsystem,
    comptime fmt: []const u8,
    args: anytype,
) void {
    self.error_logger.logDebug(subsystem, fmt, args, @src());
}

pub fn logInfo(
    self: *Engine,
    subsystem: Subsystem,
    comptime fmt: []const u8,
    args: anytype,
) void {
    self.error_logger.logInfo(subsystem, fmt, args, @src());
}

pub fn logWarning(
    self: *Engine,
    subsystem: Subsystem,
    comptime fmt: []const u8,
    args: anytype,
) void {
    self.error_logger.logWarning(subsystem, fmt, args, @src());
}

pub fn logError(
    self: *Engine,
    subsystem: Subsystem,
    comptime fmt: []const u8,
    args: anytype,
) void {
    self.error_logger.logError(subsystem, fmt, args, @src());
}

pub fn logFatal(
    self: *Engine,
    subsystem: Subsystem,
    comptime fmt: []const u8,
    args: anytype,
) void {
    self.error_logger.logFatal(subsystem, fmt, args, @src());
}

pub fn getErrors(self: *const Engine) []const ErrorEntry {
    return self.error_logger.getErrors();
}

pub fn hasErrors(self: *const Engine) bool {
    return self.error_logger.hasErrors();
}

pub fn clearErrors(self: *Engine) void {
    self.error_logger.clearErrors();
}
