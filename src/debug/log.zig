const std = @import("std");
const Allocator = std.mem.Allocator;
const EnumMap = std.EnumMap;
const SourceLocation = std.builtin.SourceLocation;
const builtin = @import("builtin");
const sink = @import("LogSink.zig");
const Sink = sink.Sink;
const ConsoleSink = sink.ConsoleSink;
const FileSink = sink.FileSink;

pub const LogLevel = enum(u8) {
    trace = 0,
    debug = 1,
    info = 2,
    warn = 3,
    err = 4,
    fatal = 5,

    pub fn getLevelName(self: LogLevel) []const u8 {
        return switch (self) {
            .trace => "TRACE",
            .debug => "DEBUG",
            .info => "INFO",
            .warn => "WARN",
            .err => "ERROR",
            .fatal => "FATAL",
        };
    }

    pub fn getAnsiColor(self: LogLevel) []const u8 {
        return switch (self) {
            .trace => "\x1b[90m", // Gray
            .debug => "\x1b[36m", // Cyan
            .info => "\x1b[32m", // Green
            .warn => "\x1b[33m", // Yellow
            .err => "\x1b[31m", // Red
            .fatal => "\x1b[35m", // Magenta
        };
    }

    // pub fn getIcon(self: LogLevel) []const u8 {
    //     return switch (self) {
    //         .error => "✘",
    //         .warn  => "⚠",
    //         .info  => "●",
    //         .debug => "◈",
    //         .trace => "⚙",
    //     };
    // }
};

pub const LogCategory = enum {
    action,
    assets,
    debug,
    ecs,
    engine,
    general,
    input,
    platform,
    registry,
    renderer,
    scene,
    sceneFormat,
    systems,
};

const LogTime = struct {
    year: u16,
    month: u8,
    day: u8,
    hour: u8,
    minute: u8,
    second: u8,

    pub fn fromTimestamp(ts: i64) LogTime {
        const epoch_seconds = std.time.epoch.EpochSeconds{ .secs = @intCast(ts) };
        const epoch_day = epoch_seconds.getEpochDay();
        const year_day = epoch_day.calculateYearDay();
        const month_day = year_day.calculateMonthDay();
        const day_seconds = epoch_seconds.getDaySeconds();
        return .{
            .year = year_day.year,
            .month = month_day.month.numeric(),
            .day = month_day.day_index,
            .hour = day_seconds.getHoursIntoDay(),
            .minute = day_seconds.getMinutesIntoHour(),
            .second = day_seconds.getSecondsIntoMinute(),
        };
    }

    pub fn formatConsole(self: LogTime, buf: []u8) ![]const u8 {
        return try std.fmt.bufPrint(buf, "({d:0>2}:{d:0>2}:{d:0>2})", .{
            self.hour,
            self.minute,
            self.second,
        });
    }

    pub fn formatISO08601(self: LogTime, buf: []u8) ![]const u8 {
        return try std.fmt.bufPrint(buf, "{:0>4}-{:0>2}-{:0>2}T{:0>2}:{:0>2}:{:0>2}Z", .{
            self.year,
            self.month,
            self.day,
            self.hour,
            self.minute,
            self.second,
        });
    }
};

pub const LogEntry = struct {
    time: LogTime,
    level: LogLevel,
    category: LogCategory,
    message: []const u8,
    // source: std.builtin.SourceLocation, // Unused right now
};

pub const Logger = struct {
    allocator: Allocator,
    sinks: []Sink,
    min_level: LogLevel,
    category_filters: EnumMap(LogCategory, ?LogLevel),
    mutex: std.Thread.Mutex,

    var global_logger: *Logger = undefined;
    var initialized: bool = false;

    pub fn init(allocator: Allocator) !void {
        global_logger = blk: {
            const ptr = try allocator.create(Logger);
            errdefer allocator.destroy(ptr);

            var sinks = try allocator.alloc(Sink, 2);
            errdefer allocator.free(sinks);

            const console_sink = try allocator.create(ConsoleSink);
            errdefer allocator.destroy(console_sink);
            console_sink.* = ConsoleSink.init();
            sinks[0] = console_sink.sink();

            const file_sink = try allocator.create(FileSink);
            errdefer allocator.destroy(file_sink);
            file_sink.* = try FileSink.init();
            sinks[1] = file_sink.sink();

            const min_level = if (builtin.mode == .Debug) .trace else .warn;
            ptr.* = .{
                .allocator = allocator,
                .sinks = sinks,
                .min_level = min_level,
                .category_filters = .{},
                .mutex = .{},
            };

            break :blk ptr;
        };
        initialized = true;
    }
    pub fn deinit() void {
        if (!initialized) return;
        const gl = Logger.global_logger;

        for (gl.sinks) |*s| {
            s.deinit(gl.allocator);
        }

        gl.allocator.free(gl.sinks);

        gl.allocator.destroy(gl);
        initialized = false;
    }
};

pub fn setMinLogLevel(level: LogLevel) void {
    Logger.global_logger.min_level = level;
}
pub fn setCategoryLevel(category: LogCategory, level: LogLevel) void {
    const gl = Logger.global_logger;
    gl.category_filters.put(category, level);
}

fn shouldLog(category: LogCategory, level: LogLevel) bool {
    const gl = Logger.global_logger;

    if (!(@intFromEnum(level) >= @intFromEnum(gl.min_level))) {
        const cat_level = gl.category_filters.get(category) orelse return false;
        if (cat_level) |cl| {
            return @intFromEnum(cl) <= @intFromEnum(level);
        } else {
            return false;
        }
    }
    return true;
}

fn internalLog(
    level: LogLevel,
    category: LogCategory,
    comptime fmt: []const u8,
    args: anytype,
) void {
    if (!shouldLog(category, level) or
        !Logger.initialized) return;
    const msg = std.fmt.allocPrint(Logger.global_logger.allocator, fmt, args) catch return;
    defer Logger.global_logger.allocator.free(msg);
    const entry: LogEntry = .{
        .category = category,
        .level = level,
        .message = msg,
        .time = LogTime.fromTimestamp(std.time.timestamp()),
    };

    for (Logger.global_logger.sinks) |*s| {
        s.write(entry);
    }
}
pub fn log(
    level: LogLevel,
    category: LogCategory,
    comptime fmt: []const u8,
    args: anytype,
) void {
    internalLog(level, category, fmt, args);
}

pub const debug_enabled = builtin.mode == .Debug;

pub const trace: fn (
    LogCategory,
    comptime []const u8,
    anytype,
) void = if (debug_enabled) traceImpl else traceStub;
fn traceImpl(
    category: LogCategory,
    comptime fmt: []const u8,
    args: anytype,
) void {
    internalLog(.trace, category, fmt, args);
}
fn traceStub(
    category: LogCategory,
    comptime fmt: []const u8,
    args: anytype,
) void {
    _ = category;
    _ = fmt;
    _ = args;
}

pub const debug: fn (
    LogCategory,
    comptime []const u8,
    anytype,
) void = if (debug_enabled) debugImpl else debugStub;
fn debugImpl(
    category: LogCategory,
    comptime fmt: []const u8,
    args: anytype,
) void {
    internalLog(.debug, category, fmt, args);
}
fn debugStub(
    category: LogCategory,
    comptime fmt: []const u8,
    args: anytype,
) void {
    _ = category;
    _ = fmt;
    _ = args;
}

pub fn info(
    category: LogCategory,
    comptime fmt: []const u8,
    args: anytype,
) void {
    internalLog(.info, category, fmt, args);
}
pub fn warn(
    category: LogCategory,
    comptime fmt: []const u8,
    args: anytype,
) void {
    internalLog(.warn, category, fmt, args);
}
pub fn err(
    category: LogCategory,
    comptime fmt: []const u8,
    args: anytype,
) void {
    internalLog(.err, category, fmt, args);
}
pub fn fatal(
    category: LogCategory,
    comptime fmt: []const u8,
    args: anytype,
) void {
    internalLog(.fatal, category, fmt, args);
}
