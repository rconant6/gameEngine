const std = @import("std");
const plat = @import("platform");
const rend = @import("renderer");
const debug = @import("debug");
const Logger = debug.Logger;
const log = debug.log;

pub const AppConfig = struct {
    title: []const u8,
    width: u32 = 1024,
    height: u32 = 768,
    resizable: bool = true,
    // future flags:
    // assets: bool = false,
    // file_dialogs: bool = false,
    // ecs: bool = false,
};

pub const App = struct {
    allocator: std.mem.Allocator,
    window: *plat.Window,
    renderer: rend.Renderer,
    logical_width: u32,
    logical_height: u32,

    pub fn init(allocator: std.mem.Allocator, config: AppConfig) !App {
        try Logger.init(allocator);

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

        const renderer = rend.Renderer.init(allocator, .{
            .width = scaled_width,
            .height = scaled_height,
            .native_handle = window.handle,
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
            .allocator = allocator,
            .window = window,
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
        try self.renderer.beginFrame();
    }

    pub fn endFrame(self: *App) !void {
        try self.renderer.endFrame();
    }
};
