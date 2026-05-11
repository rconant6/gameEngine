const std = @import("std");
const Allocator = std.mem.Allocator;
const net = std.Io.net;
const plat = @import("platform.zig");
const wire = @import("linux/wayland/wire.zig");
const ObjIdAllocator = wire.ObjIdAllocator;
const WlFixed = wire.WlFixed;
const WlHeader = wire.Header;
const WlConnection = wire.Connection;
const faces = @import("linux/wayland/interfaces.zig");
const WlDisplay = faces.WlDisplay;
const WlRegistry = faces.WlRegistry;
const WlCompositor = faces.WlCompositor;
const WlSeat = faces.WlSeat;
const Event = plat.Event;
const KeyModifiers = plat.KeyModifiers;
const WindowConfig = plat.WindowConfig;
const Capabilities = plat.Capabilities;
const DisplayInfo = plat.DisplayInfo;
const V2I = @import("math").V2I;
const log = @import("debug").log;

pub const Window = struct {
    surface_id: u32, // wl_surface
    xdg_surface_id: u32, // xdg_surface wrapper
    xdg_toplevel_id: u32, // xdg_toplevel (the actual window)
    configured: bool, // has compositor sent configure+ack?

    width: u32,
    height: u32,
    should_close: bool,

    events: [64]Event,
    event_head: usize,
    event_tail: usize,

    pub fn deinit(self: *Window) void {
        _ = self;
    }

    pub fn shouldClose(self: *const Window) bool {
        return self.should_close;
    }

    pub fn swapBuffers(self: *const Window, offset: u32) void {
        _ = self;
        _ = offset;
    }

    fn pushEvent(self: *Window, event: Event) void {
        self.events[self.event_tail % 64] = event;
        self.event_tail += 1;
    }

    fn popEvent(self: *Window) ?Event {
        if (self.event_head == self.event_tail) return null;
        const event = self.events[self.event_head % 64];
        self.event_head += 1;
        return event;
    }
};

var conn: *WlConnection = undefined;
const display_id: u32 = 1; // always 1, set by protocol

var display_proxy: wire.Proxy(WlDisplay) = undefined;
var registry_proxy: wire.Proxy(WlRegistry) = undefined;
var compositor_proxy: wire.Proxy(WlCompositor) = undefined;
var seat_proxy: wire.Proxy(WlSeat) = undefined;

const BoundGlobal = struct {
    name: u32 = 0,
    version: u32 = 0,
    obj_id: u32 = 0,
    interface: []const u8 = "",
};

var compositor: BoundGlobal = .{};
var seat: BoundGlobal = .{};
var xdg_wm_base: BoundGlobal = .{};

pub fn init(gpa: Allocator, io: std.Io, env: *std.process.Environ.Map) !void {
    conn = try WlConnection.init(gpa, io, env);
    display_proxy = .{
        .conn = conn,
        .obj_id = display_id,
        .on_event = onDisplayEvent,
    };
    try conn.registerProxy(WlDisplay, &display_proxy);

    const registry_id = conn.ids.alloc();
    log.debug(.platform, "registry id: {d}", .{registry_id});
    registry_proxy = .{
        .obj_id = registry_id,
        .conn = conn,
        .on_event = onRegistryEvent,
    };
    try conn.registerProxy(WlRegistry, &registry_proxy);
    try display_proxy.send(.{ .get_registry = .{ .registry = registry_id } });

    const cb_id = conn.ids.alloc();
    log.debug(.platform, "callback id: {d}", .{cb_id});
    try display_proxy.send(.{ .sync = .{ .callback = cb_id } });
    try conn.drain(cb_id);

    log.info(
        .platform,
        "Globals enumerated: compositor: {d}, xdg_wm_base: {d} seat: {d}",
        .{ compositor.name, xdg_wm_base.name, seat.name },
    );

    compositor.obj_id = conn.ids.alloc();
    log.debug(.platform, "compositor id: {d}", .{compositor.obj_id});
    try registry_proxy.send(.{ .bind = .{
        .name = compositor.name,
        .interface = compositor.interface,
        .version = compositor.version,
        .new_id = compositor.obj_id,
    } });
    compositor_proxy = .{
        .obj_id = compositor.obj_id,
        .conn = conn,
        .on_event = onCompositorEvent,
    };
    try conn.registerProxy(WlCompositor, &compositor_proxy);

    seat.obj_id = conn.ids.alloc();
    log.debug(.platform, "seat id: {d}", .{seat.obj_id});
    try registry_proxy.send(.{ .bind = .{
        .name = seat.name,
        .interface = seat.interface,
        .version = seat.version,
        .new_id = seat.obj_id,
    } });
    seat_proxy = .{
        .obj_id = seat.obj_id,
        .conn = conn,
        .on_event = onSeatEvent,
    };
    try conn.registerProxy(WlSeat, &seat_proxy);

    try display_proxy.send(.{ .sync = .{ .callback = cb_id } });
    try conn.drain(cb_id);
}
pub fn deinit() void {
    compositor_proxy.send(.{
        .release = .{},
    }) catch |e| {
        log.err(.platform, "Unable to release the compositor: {any}", .{e});
    };
    conn.deinit();
}

fn onSeatEvent(event: WlSeat.Event) !void {
    switch (event) {
        .capabilities => |c| log.info(.platform, "Seat capes: {d}", .{c.capes}),
        .name => |s| log.info(.platform, "Seat name: {s}", .{s.name}),
    }
}
fn onDisplayEvent(event: WlDisplay.Event) !void {
    switch (event) {
        .err => |e| {
            log.err(
                .platform,
                "wl_display error: obj: {d} code: {d} msg: {s}",
                .{ e.object_id, e.code, e.msg },
            );
            return error.WaylandProtocolError;
        },
        .delete_id => {},
    }
}
fn onRegistryEvent(event: WlRegistry.Event) !void {
    switch (event) {
        .global => |g| {
            log.info(
                .platform,
                "GLOBAL: {d}  {s}  v:{}",
                .{ g.name, g.interface, g.version },
            );
            if (std.mem.eql(u8, g.interface, "wl_compositor")) {
                compositor.interface = "wl_compositor";
                compositor.name = g.name;
                compositor.version = g.version;
            } else if (std.mem.eql(u8, g.interface, "xdg_wm_base")) {
                xdg_wm_base.interface = "xdg_wm_base";
                xdg_wm_base.name = g.name;
                xdg_wm_base.version = g.version;
            } else if (std.mem.eql(u8, g.interface, "wl_seat")) {
                seat.interface = "wl_seat";
                seat.name = g.name;
                seat.version = g.version;
            }
        },
        .global_remove => {},
    }
}
fn onCompositorEvent(event: WlCompositor.Event) !void {
    switch (event) {}
    return;
}

pub fn createWindow(config: WindowConfig) !*Window {
    _ = config;
    return error.NotImplemented;
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
    return null;
}

pub fn waitEvent() Event {
    return .NullEvent;
}

pub fn setMouseCursorVisible(window: *Window, visible: bool) void {
    _ = window;
    _ = visible;
}

pub fn setMouseCursorLocked(window: *Window, locked: bool) void {
    _ = window;
    _ = locked;
}

pub fn getTime() f64 {
    return @floatFromInt(std.time.milliTimestamp());
}

pub fn sleep(seconds: f64) void {
    std.time.sleep(@intFromFloat(seconds * std.time.ns_per_s));
}

pub fn getNativeWindowHandle(window: *Window) *anyopaque {
    return window;
}

pub fn getWindowScaleFactor(window: *Window) f32 {
    _ = window;
    return 1.0;
}

pub fn getDisplays(allocator: std.mem.Allocator) ![]DisplayInfo {
    _ = allocator;
    return &.{};
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
        .has_opengl = true,
        .has_metal = false,
        .has_file_dialogs = false,
        .has_clipboard = false,
    };
}
