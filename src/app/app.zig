const std = @import("std");
const plat = @import("platform");
const rend = @import("renderer");
const debug = @import("debug");
const math = @import("math");
const Memory = @import("memory");
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
    mem: *Memory,
    io: std.Io,
    window: *plat.Window,
    kb: *const plat.Keyboard,
    mouse: *const plat.Mouse,
    renderer: rend.Renderer,
    logical_width: u32,
    logical_height: u32,
    scale_factor: f32, // physical / logical, from backingScaleFactor; sourced once at init

    pub fn init(
        backing: std.mem.Allocator,
        io: std.Io,
        env: *std.process.Environ.Map,
        config: AppConfig,
    ) !App {
        const mem = try backing.create(Memory);
        mem.init(backing);

        try Logger.init(mem.persistent, io);

        plat.init(mem.persistent, io, env) catch |err| {
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
        const window_size = plat.getWindowSize(window);
        const scaled_width: u32 = @intFromFloat(@as(f32, @floatFromInt(window_size.width)) * scale_factor);
        const scaled_height: u32 = @intFromFloat(@as(f32, @floatFromInt(window_size.height)) * scale_factor);

        const renderer = rend.Renderer.init(mem.persistent, io, .{
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
            .mem = mem,
            .io = io,
            .window = window,
            .kb = plat.getKeyboard(),
            .mouse = plat.getMouse(),
            .renderer = renderer,
            .logical_width = window_size.width,
            .logical_height = window_size.height,
            .scale_factor = scale_factor,
        };
    }

    pub fn deinit(self: *App) void {
        log.info(.general, "App shutting down...", .{});
        self.renderer.deinit();
        self.window.deinit();
        plat.deinit();
        Logger.deinit();
        // `persistent` IS the raw backing allocator (Memory.init assigns it
        // directly). Capture it before deinit so we can free Memory itself.
        const backing = self.mem.persistent;
        self.mem.deinit();
        backing.destroy(self.mem);
    }

    pub fn isRunning(self: *const App) bool {
        return !self.window.shouldClose();
    }

    pub fn beginFrame(self: *App) !void {
        self.mem.tickFrame();
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
