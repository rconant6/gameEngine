const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const log = @import("log.zig");
const LogEntry = log.LogEntry;
const LogCategory = log.LogCategory;

const reset = "\x1b[0m";
const bold = "\x1b[1m";
const dim = "\x1b[2m";
const italic = "\x1b[3m";
const white = "\x1b[37m";
const grey = "\x1b[90m";
const cyan = "\x1b[36m";
const bold_white = white ++ bold;

/// ConsoleSink immidiately writes to the console
/// showing the level, category, user message and simple timestamp
pub const ConsoleSink = struct {
    const Self = @This();

    stderr: std.fs.File,
    buffer: [4096]u8,
    writer: std.Io.Writer,

    pub fn init() Self {
        const stderr = std.fs.File.stderr();
        var self = Self{
            .stderr = stderr,
            .buffer = undefined,
            .writer = undefined,
        };
        self.writer = stderr.writer(&self.buffer).interface;
        return self;
    }
    pub fn sink(self: *Self) Sink {
        return .{
            .ptr = self,
            .vtable = &.{
                .write = writeFn,
                .flush = flushFn,
                .deinit = deinitFn,
            },
        };
    }
    fn writeFn(ptr: *anyopaque, entry: LogEntry) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.write(entry);
    }
    fn flushFn(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.flush();
    }
    fn deinitFn(ptr: *anyopaque, gpa: Allocator) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.deinit(gpa);
    }
    pub fn write(self: *Self, entry: LogEntry) void {
        const level_color = entry.level.getAnsiColor();
        var time_buf: [10]u8 = undefined;
        const time_str = entry.time.formatConsole(&time_buf) catch "(00:00:00)";
        // Layout: [LEVEL] CATEGORY: MESSAGE  TIME
        self.writer.print("{s}[{s:}]{s} {s:}: {s}{s}{s}  {s}{s}{s}\n", .{
            // Level
            level_color,
            entry.level.getLevelName(),
            reset,

            // Category
            @tagName(entry.category),

            // THE MESSAGE (Bold White Focus)
            bold_white,
            entry.message,
            reset,

            // Timestamp (Cyan)
            cyan,
            time_str,
            reset,
        }) catch return;

        self.writer.flush() catch return;
    }
    pub fn flush(self: *Self) void {
        _ = self;
        // self.writer.flush() catch return;
    }
    pub fn deinit(self: *Self, gpa: Allocator) void {
        gpa.destroy(self);
    }
};

/// FileSink batch writes logs to a rotating pool of files
/// that are located in logs/
/// game.log is the most recent run and stores game_(1-4).log for storage
/// of previous runs.
/// game_4.log gets removed on each run and 1-3 will shuffle down one per run
pub const FileSink = struct {
    const Self = @This();
    const log_files = [_][]const u8{
        "game.log",
        "game.1.log",
        "game.2.log",
        "game.3.log",
        "game.4.log",
    };

    log_dir: std.fs.Dir,
    log_file: std.fs.File,
    log_buffer: [65336]u8,
    writer: std.Io.Writer,
    entry_count: usize = 0,
    enabled: bool = false,

    pub fn init() !Self {
        var log_dir = getLogDir() catch |err| {
            std.debug.print("Unable to get logs directory: {any}\n", .{err});
            return error.FailedToCreateFileLogger;
        };
        try rotateLogs(log_dir);

        var self = Self{
            .log_dir = try getLogDir(),
            .log_file = try log_dir.createFile(log_files[0], .{}),
            .log_buffer = undefined,
            .writer = undefined,
            .enabled = true,
        };
        self.writer = self.log_file.writer(&self.log_buffer).interface;

        return self;
    }
    pub fn sink(self: *Self) Sink {
        return .{
            .ptr = self,
            .vtable = &.{
                .write = writeFn,
                .flush = flushFn,
                .deinit = deinitFn,
            },
        };
    }
    fn writeFn(ptr: *anyopaque, entry: LogEntry) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.write(entry);
    }
    fn flushFn(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.flush();
    }
    pub fn deinitFn(ptr: *anyopaque, gpa: Allocator) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.deinit(gpa);
    }

    pub fn write(self: *Self, entry: LogEntry) void {
        if (!self.enabled) return;
        if (self.entry_count > 100) self.flush();

        var time_buf: [20]u8 = undefined;
        const time_str = entry.time.formatISO08601(&time_buf) catch "0000-00-00T00:00:00Z";

        // Layout: LEVEL category message time\n
        self.writer.print(
            "{s:<5}  {s:<10}  {s}  {s:>20}\n",
            .{
                entry.level.getLevelName(),
                @tagName(entry.category),
                entry.message,
                time_str,
            },
        ) catch {};

        self.entry_count += 1;
    }
    pub fn flush(self: *Self) void {
        if (!self.enabled) return;

        self.writer.flush() catch {};
        self.log_file.sync() catch {};

        self.entry_count = 0;
    }

    pub fn deinit(self: *Self, gpa: Allocator) void {
        self.flush();
        self.log_file.close();
        self.log_dir.close();
        gpa.destroy(self);
    }

    fn getLogDir() !std.fs.Dir {
        var exe_path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const exe_dir_path = try std.fs.selfExeDirPath((&exe_path_buf));
        const exe_dir = std.fs.path.dirname(exe_dir_path) orelse ".";

        var log_path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const log_path = try std.fmt.bufPrint(&log_path_buf, "{s}/logs", .{exe_dir});

        try std.fs.cwd().makePath(log_path);
        return try std.fs.cwd().openDir(log_path, .{});
    }

    fn rotateLogs(dir: std.fs.Dir) !void {
        const max_rotations = log_files.len;
        dir.deleteFile(log_files[max_rotations - 1]) catch |err| switch (err) {
            error.FileNotFound => {},
            else => return err,
        };

        var i: usize = max_rotations - 1;
        while (i > 0) : (i -= 1) {
            dir.rename(log_files[i - 1], log_files[i]) catch |err| switch (err) {
                error.FileNotFound => continue,
                else => return err,
            };
        }
    }
};

pub const Sink = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        write: *const fn (ptr: *anyopaque, entry: LogEntry) void,
        flush: *const fn (ptr: *anyopaque) void,
        deinit: *const fn (ptr: *anyopaque, gpa: Allocator) void,
    };

    pub fn write(self: Sink, entry: LogEntry) void {
        self.vtable.write(self.ptr, entry);
    }

    pub fn flush(self: Sink) void {
        self.vtable.flush(self.ptr);
    }

    pub fn deinit(self: *Sink, gpa: Allocator) void {
        self.vtable.deinit(self.ptr, gpa);
    }
};
