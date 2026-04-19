const std = @import("std");
const plat = @import("platform");
const rend = @import("renderer");
const debug = @import("debug");
const Logger = debug.Logger;
const log = debug.log;

pub const AppConfig = struct {
    title: []const u8,
    width: u32 = 1920,
    height: u32 = 1080,
    resizable: bool = true,
    // future flags:
    // assets: bool = false,
    // file_dialogs: bool = false,
    // ecs: bool = false,
};

pub const App = struct {
    gpa: std.mem.Allocator,
    io: std.Io,
    window: *plat.Window,
    kb: *const plat.Keyboard,
    mouse: *const plat.Mouse,
    renderer: rend.Renderer,
    logical_width: u32,
    logical_height: u32,

    pub fn init(gpa: std.mem.Allocator, io: std.Io, config: AppConfig) !App {
        try Logger.init(gpa, io);

        plat.init() catch |err| {
            log.fatal(.platform, "Failed to start platform layer: {any}", .{err});
            @panic("App: platform init failed");
        };

        const window = plat.createWindow(.{
            .title = config.title,
            .width = config.width,
            .height = config.height,
            .resizable = config.resizable,
        }) catch |err| {
            log.fatal(.platform, "Failed to create window: {any}", .{err});
            @panic("App: window creation failed");
        };
        log.info(
            .platform,
            "Window created: {s} ({d}x{d})",
            .{ config.title, config.width, config.height },
        );

        const scale_factor = plat.getWindowScaleFactor(window);
        const f_width: f32 = @floatFromInt(config.width);
        const f_height: f32 = @floatFromInt(config.height);
        const scaled_width: u32 = @intFromFloat(f_width * scale_factor);
        const scaled_height: u32 = @intFromFloat(f_height * scale_factor);

        const renderer = rend.Renderer.init(gpa, io, .{
            .width = scaled_width,
            .height = scaled_height,
            .native_handle = plat.getNativeWindowHandle(window),
        }) catch |err| {
            log.fatal(.renderer, "Renderer init failed: {any}", .{err});
            @panic("App: renderer init failed");
        };
        log.info(
            .renderer,
            "Renderer initialized: {d}x{d} (scaled)",
            .{ scaled_width, scaled_height },
        );

        return App{
            .gpa = gpa,
            .io = io,
            .window = window,
            .kb = plat.getKeyboard(),
            .mouse = plat.getMouse(),
            .renderer = renderer,
            .logical_width = config.width,
            .logical_height = config.height,
        };
    }

    pub fn deinit(self: *App) void {
        log.info(.general, "App shutting down...", .{});
        self.renderer.deinit();
        self.window.deinit();
        Logger.deinit();
    }

    pub fn isRunning(self: *const App) bool {
        return !self.window.shouldClose();
    }

    pub fn beginFrame(self: *App) !void {
        plat.clearInputStates();
        while (plat.pollEvent()) |_| {}
        self.renderer.beginFrame() catch |err| {
            log.err(.renderer, "BeginFrame failed: {any}", .{err});
        };
    }

    pub fn endFrame(self: *App) !void {
        try self.renderer.endFrame();
    }
};
