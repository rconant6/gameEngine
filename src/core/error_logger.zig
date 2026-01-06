const std = @import("std");
const Allocator = std.mem.Allocator;

const is_debug = @import("builtin").mode == .Debug;

pub const Severity = enum(u8) {
    debug,
    info,
    warn,
    err,
    fatal,
};

pub const SubSystem = enum {
    engine,
    renderer,
    scene,
    assets,
    ecs,
    platform,
    input,

    pub fn toString(self: SubSystem) []const u8 {
        return @tagName(self);
    }
};

pub const ErrorEntry = struct {
    timestamp: i64,
    severity: Severity,
    subsystem: SubSystem,
    message: []const u8,
    source_file: []const u8,
    source_line: u32,
    source_fn: []const u8,
};

const MSG_MAX_SIZE: u32 = 256;

pub const ErrorLogger = struct {
    allocator: Allocator,

    entries: [100]ErrorEntry,
    write_index: usize,
    count: usize,

    message_buffer: [100 * MSG_MAX_SIZE]u8,
    message_write_offset: usize,

    min_severity: Severity,

    pub fn init(allocator: Allocator) ErrorLogger {
        return .{
            .allocator = allocator,
            .entries = undefined,
            .write_index = 0,
            .count = 0,
            .message_buffer = undefined,
            .message_write_offset = 0,
            .min_severity = if (is_debug) .debug else .warn,
        };
    }
    pub fn deinit(self: *ErrorLogger) void {
        _ = self;
    }

    fn logInternal(
        self: *ErrorLogger,
        severity: Severity,
        subsystem: SubSystem,
        comptime fmt: []const u8,
        args: anytype,
        src: std.builtin.SourceLocation,
    ) void {
        if (@intFromEnum(severity) < @intFromEnum(self.min_severity)) return;

        const timestamp = std.time.milliTimestamp();

        const msg_slot_start = self.write_index * MSG_MAX_SIZE;
        const msg_slot = self.message_buffer[msg_slot_start..][0..MSG_MAX_SIZE];

        const message =
            std.fmt.bufPrint(msg_slot, fmt, args) catch |err| blk: {
                break :blk std.fmt.bufPrint(
                    msg_slot,
                    "[Error formatting message: {}]",
                    .{err},
                ) catch break :blk "[Message format error]";
            };

        self.entries[self.write_index] = ErrorEntry{
            .timestamp = timestamp,
            .severity = severity,
            .subsystem = subsystem,
            .message = message,
            .source_file = src.file,
            .source_line = src.line,
            .source_fn = src.fn_name,
        };

        const subsystem_name = subsystem.toString();
        switch (severity) {
            .debug => std.log.debug("[{s}] {s}", .{ subsystem_name, message }),
            .info => std.log.info("[{s}] {s}", .{ subsystem_name, message }),
            .warn => std.log.warn("[{s}] {s}", .{ subsystem_name, message }),
            .err => std.log.err("[{s}] {s}", .{ subsystem_name, message }),
            .fatal => std.log.err("[{s}] FATAL: {s}", .{ subsystem_name, message }),
        }

        self.count += 1;
        self.write_index += 1;
    }
    pub fn logInfo(
        self: *ErrorLogger,
        subsystem: SubSystem,
        comptime fmt: []const u8,
        args: anytype,
        src: std.builtin.SourceLocation,
    ) void {
        self.logInternal(.info, subsystem, fmt, args, src);
    }
    pub fn logWarning(
        self: *ErrorLogger,
        subsystem: SubSystem,
        comptime fmt: []const u8,
        args: anytype,
        src: std.builtin.SourceLocation,
    ) void {
        self.logInternal(.warn, subsystem, fmt, args, src);
    }
    pub fn logError(
        self: *ErrorLogger,
        subsystem: SubSystem,
        comptime fmt: []const u8,
        args: anytype,
        src: std.builtin.SourceLocation,
    ) void {
        self.logInternal(.err, subsystem, fmt, args, src);
    }
    pub fn logDebug(
        self: *ErrorLogger,
        subsystem: SubSystem,
        comptime fmt: []const u8,
        args: anytype,
        src: std.builtin.SourceLocation,
    ) void {
        self.logInternal(.debug, subsystem, fmt, args, src);
    }

    pub fn logFatal(
        self: *ErrorLogger,
        subsystem: SubSystem,
        comptime fmt: []const u8,
        args: anytype,
        src: std.builtin.SourceLocation,
    ) void {
        self.logInternal(.fatal, subsystem, fmt, args, src);
        if (is_debug) {
            @panic("Fatal error logged");
        }
    }
    pub fn getErrors(self: *const ErrorLogger) []const ErrorEntry {
        std.debug.assert(self.count <= 100);

        return self.entries[0..self.count];
    }
    pub fn getErrorCount(self: *const ErrorLogger) usize {
        return self.count;
    }
    pub fn hasErrors(self: *const ErrorLogger) bool {
        return self.count > 0;
    }
    pub fn clearErrors(self: *ErrorLogger) void {
        self.write_index = 0;
        self.count = 0;
        self.message_write_offset = 0;
    }

    // Configuration
    pub fn setMinSeverity(self: *ErrorLogger, severity: Severity) void {
        self.min_severity = severity;
    }
};
