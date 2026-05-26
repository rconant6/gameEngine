const std = @import("std");
const Allocator = std.mem.Allocator;
const log = @import("debug").log;
const plat = @import("platform.zig");
const Capabilities = plat.Capabilities;
const DisplayInfo = plat.DisplayInfo;
const Event = plat.Event;
const WindowConfig = plat.WindowConfig;
const wl = @import("linux/wayland.zig");
const WaylandState = wl.WaylandState;
const WindowState = wl.WindowState;
const Proxy = wl.Proxy;
const handlers = wl.handlers;
const c = wl.c;

var gpa: Allocator = undefined;
var ws: *WaylandState = undefined;
var active_window: ?*Window = null;

const WindowHandle = struct {
    display: *anyopaque,
    surface: *anyopaque,
    drm_device: u64,
};

pub const Window = struct {
    state: WindowState,

    pub fn deinit(self: *Window) void {
        self.state.events.deinit();
        // TODO: destroy xdg_toplevel, xdg_surface, surface in reverse order
        gpa.destroy(self);
    }

    pub fn shouldClose(self: *const Window) bool {
        return self.state.should_close;
    }

    pub fn swapBuffers(self: *const Window, offset: u32) void {
        _ = self;
        _ = offset;
    }
};

pub fn init(alloc: Allocator, io: std.Io, env: *std.process.Environ.Map) !void {
    _ = io;
    _ = env;
    gpa = alloc;
    ws = try alloc.create(WaylandState);
    ws.dmafeedback = .{}; // alloc.create doesn't zero-init

    ws.display = c.wl_display_connect(null) orelse return error.WaylandConnectFailed;
    log.info(.platform, "Wayland display connected", .{});

    ws.registry = c.wl_display_get_registry(ws.display) orelse return error.WaylandRegistryFailed;

    var reg_proxy = Proxy(wl.WlRegistry){
        .ptr = @ptrCast(ws.registry),
        .handler = handlers.onRegistryEvent,
        .ctx = ws,
    };
    reg_proxy.listen();
    _ = c.wl_display_roundtrip(ws.display); // fills BoundObject.name/version for known globals

    const compositor_raw = c.wl_registry_bind(
        ws.registry,
        ws.compositor.name,
        &c.wl_compositor_interface,
        @min(ws.compositor.version, 4),
    ) orelse return error.WaylandBindCompositorFailed;
    ws.compositor.proxy = .{ .ptr = compositor_raw, .handler = handlers.onCompositorEvent, .ctx = ws };
    ws.compositor.proxy.listen();

    const xdg_raw = c.wl_registry_bind(
        ws.registry,
        ws.xdg_wm_base.name,
        &c.xdg_wm_base_interface,
        @min(ws.xdg_wm_base.version, 1),
    ) orelse return error.WaylandBindXdgFailed;
    ws.xdg_wm_base.proxy = .{ .ptr = xdg_raw, .handler = handlers.onXdgWmBaseEvent, .ctx = ws };
    ws.xdg_wm_base.proxy.listen();

    const seat_raw = c.wl_registry_bind(
        ws.registry,
        ws.seat.name,
        &c.wl_seat_interface,
        @min(ws.seat.version, 5),
    ) orelse return error.WaylandBindSeatFailed;
    ws.seat.proxy = .{ .ptr = seat_raw, .handler = handlers.onSeatEvent, .ctx = ws };
    ws.seat.proxy.listen();

    const output_raw = c.wl_registry_bind(
        ws.registry,
        ws.output.name,
        &c.wl_output_interface,
        @min(ws.output.version, 2),
    ) orelse return error.WaylandBindOutputFailed;
    ws.output.proxy = .{ .ptr = output_raw, .handler = handlers.onOutputEvent, .ctx = ws };
    ws.output.proxy.listen();

    const dmabuf_raw = c.wl_registry_bind(
        ws.registry,
        ws.dmabuf.name,
        &c.zwp_linux_dmabuf_v1_interface,
        @min(ws.dmabuf.version, 4),
    ) orelse return error.WaylandBindDmabufFailed;
    ws.dmabuf.proxy = .{ .ptr = dmabuf_raw, .handler = handlers.onZwpLinuxDmabuf, .ctx = ws };
    ws.dmabuf.proxy.listen();

    _ = c.wl_display_roundtrip(ws.display); // fires seat capabilities + output mode/scale

    log.info(.platform, "Wayland init complete", .{});
}

pub fn deinit() void {
    // TODO: destroy bound objects in reverse order
    c.wl_display_disconnect(ws.display);
    gpa.destroy(ws);
}

pub fn createWindow(config: WindowConfig) !*Window {
    const win = try gpa.create(Window);
    win.state.width = config.width;
    win.state.height = config.height;
    win.state.configure_serial = 0;
    win.state.configured = false;
    win.state.should_close = false;
    win.state.configured_width = 0;
    win.state.configured_height = 0;
    win.state.surface = .{};
    win.state.xdg_surface = .{};
    win.state.xdg_toplevel = .{};
    win.state.events = try @TypeOf(win.state.events).init(gpa);

    const compositor: *c.wl_compositor = @ptrCast(@alignCast(ws.compositor.proxy.ptr));
    const surface = c.wl_compositor_create_surface(compositor) orelse return error.SurfaceCreateFailed;
    win.state.surface.proxy = .{ .ptr = @ptrCast(surface), .handler = handlers.onSurfaceEvent, .ctx = win };
    win.state.surface.proxy.listen();

    const dmabuf_ptr: *c.zwp_linux_dmabuf_v1 = @ptrCast(@alignCast(ws.dmabuf.proxy.ptr));
    const feedback_raw = c.zwp_linux_dmabuf_v1_get_surface_feedback(dmabuf_ptr, surface) orelse return error.DmabufFeedbackFailed;
    var feedback_proxy = Proxy(wl.ZwpLinuxDmabufFeedback){
        .ptr = @ptrCast(feedback_raw),
        .handler = handlers.onZwpLInuxDmabufFeedback,
        .ctx = ws,
    };
    feedback_proxy.listen();
    _ = c.wl_display_roundtrip(ws.display); // receive dmabuf feedback → populates ws.dmafeedback.target_device

    const xdg_base: *c.xdg_wm_base = @ptrCast(@alignCast(ws.xdg_wm_base.proxy.ptr));
    const xdg_surf = c.xdg_wm_base_get_xdg_surface(xdg_base, surface) orelse return error.XdgSurfaceCreateFailed;
    win.state.xdg_surface.proxy = .{ .ptr = @ptrCast(xdg_surf), .handler = handlers.onXdgSurfaceEvent, .ctx = win };
    win.state.xdg_surface.proxy.listen();

    const toplevel = c.xdg_surface_get_toplevel(xdg_surf) orelse return error.ToplevelCreateFailed;
    win.state.xdg_toplevel.proxy = .{ .ptr = @ptrCast(toplevel), .handler = handlers.onXdgToplevelEvent, .ctx = win };
    win.state.xdg_toplevel.proxy.listen();

    const title_z = try gpa.dupeZ(u8, config.title);
    defer gpa.free(title_z);
    c.xdg_toplevel_set_title(toplevel, title_z.ptr);

    if (true) {
        c.xdg_toplevel_set_fullscreen(toplevel, null);
    }

    c.wl_surface_commit(surface);
    _ = c.wl_display_roundtrip(ws.display); // compositor sends configure, handler stores serial

    if (win.state.configured_width > 0) win.state.width = win.state.configured_width;
    if (win.state.configured_height > 0) win.state.height = win.state.configured_height;

    active_window = win;

    return win;
}

pub fn setPixelBuffer(window: *Window, pixels: []const u8, width: u32, height: u32) void {
    _ = window;
    _ = pixels;
    _ = width;
    _ = height;
}

pub fn swapBuffers(window: *Window, offset: u32) void {
    _ = window;
    _ = offset;
}

pub fn pollNextEvent() ?Event {
    _ = c.wl_display_flush(ws.display);
    const fd = c.wl_display_get_fd(ws.display);
    var pfd = std.posix.pollfd{ .fd = fd, .events = std.posix.POLL.IN, .revents = 0 };
    _ = std.posix.poll((&pfd)[0..1], 0) catch {};
    if (pfd.revents & std.posix.POLL.IN != 0) {
        _ = c.wl_display_dispatch(ws.display);
    } else {
        _ = c.wl_display_dispatch_pending(ws.display);
    }
    return (active_window orelse return null).state.events.popFront();
}

pub fn waitEvent() Event {
    _ = c.wl_display_dispatch(ws.display);
    return (active_window orelse return .NullEvent).state.events.popFront() orelse .NullEvent;
}

pub fn setMouseCursorVisible(window: *Window, visible: bool) void {
    _ = window;
    _ = visible;
}

pub fn setMouseCursorLocked(window: *Window, locked: bool) void {
    _ = window;
    _ = locked;
}

/// Caller must destroy the returned handle
pub fn getNativeWindowHandle(window: *Window) *anyopaque {
    const wh = gpa.create(WindowHandle) catch |err| {
        log.err(.platform, "Unable to get window handle: {}", .{err});
        return undefined;
    };
    wh.* = .{
        .display = @ptrCast(ws.display),
        .surface = window.state.surface.proxy.ptr,
        .drm_device = ws.dmafeedback.target_device,
    };
    return wh;
}

pub fn getWindowSize(window: *Window) plat.WindowSize {
    return .{ .width = window.state.width, .height = window.state.height };
}

pub fn getWindowScaleFactor(window: *Window) f32 {
    _ = window;
    const scale = ws.output_info.scale;
    return if (scale > 0) @floatFromInt(scale) else 1.0;
}

pub fn getDisplays(allocator: std.mem.Allocator) ![]DisplayInfo {
    const displays = try allocator.alloc(DisplayInfo, 1);
    displays[0] = .{
        .name = "Wayland Output",
        .width = @intCast(ws.output_info.width),
        .height = @intCast(ws.output_info.height),
        .refresh_rate = @intCast(@divTrunc(ws.output_info.refresh, 1000)),
        .is_primary = true,
    };
    return displays;
}

pub fn getClipboardText(allocator: std.mem.Allocator) ![]const u8 {
    _ = allocator;
    return error.NotImplemented;
}

pub fn setClipboardText(text: []const u8) !void {
    _ = text;
    return error.NotImplemented;
}

pub fn getCapabilities() Capabilities {
    return .{
        .has_vulkan = true,
        .has_opengl = false,
        .has_metal = false,
        .has_file_dialogs = false,
        .has_clipboard = false,
    };
}
