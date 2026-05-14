const std = @import("std");
const Allocator = std.mem.Allocator;
const net = std.Io.net;
const wire = @import("linux/wayland/wire.zig");
const WlConnection = wire.Connection;
const faces = @import("linux/wayland/interfaces.zig");
const WlCompositor = faces.WlCompositor;
const WlDisplay = faces.WlDisplay;
const WlKeyboard = faces.WlKeyboard;
const WlOutput = faces.WlOutput;
const WlPointer = faces.WlPointer;
const WlRegistry = faces.WlRegistry;
const WlSeat = faces.WlSeat;
const WlSeatCape = faces.WlSeatCape;
const WlSurface = faces.WlSurface;
const XdgSurface = faces.XdgSurface;
const XdgToplevel = faces.XdgToplevel;
const XdgWmBase = faces.XdgWmBase;
const state = @import("linux/wayland/state.zig");
const WlWindow = state.WindowState;
const BoundObject = state.BoundObject;
const WaylandState = state.WaylandState;
const OuputInfo = state.OutputInfo;
const handlers = @import("linux/wayland/handlers.zig");
const consts = @import("linux/wayland/consts.zig");

const plat = @import("platform.zig");
const Capabilities = plat.Capabilities;
const DisplayInfo = plat.DisplayInfo;
const Event = plat.Event;
const KeyModifiers = plat.KeyModifiers;
const WindowConfig = plat.WindowConfig;

const V2I = @import("math").V2I;
const log = @import("debug").log;

var gpa: Allocator = undefined;
var wl: *WaylandState = undefined;

fn startWayland(empty_state: *WaylandState) !void {
    empty_state.display_proxy = .{
        .obj_id = 1, // display is always 1 per protocol
        .ctx = empty_state,
        .on_event = handlers.onDisplayEvent,
    };
    try empty_state.conn.registerProxy(WlDisplay, &empty_state.display_proxy);

    empty_state.registry_proxy = .{
        .obj_id = empty_state.conn.ids.alloc(),
        .ctx = empty_state,
        .on_event = handlers.onRegistryEvent,
    };
    try empty_state.conn.registerProxy(WlRegistry, &empty_state.registry_proxy);
    try empty_state.display_proxy.send(
        empty_state.conn,
        WlDisplay.Request{
            .get_registry = .{ .registry = empty_state.registry_proxy.obj_id },
        },
    );
    try empty_state.conn.roundTrip();
}

pub fn init(alloc: Allocator, io: std.Io, env: *std.process.Environ.Map) !void {
    gpa = alloc;
    wl = try gpa.create(WaylandState);
    wl.conn = try WlConnection.init(gpa, io, env);

    try startWayland(wl);

    log.info(
        .platform,
        "Used globals enumerated:\n compositor: {d}\n xdg_wm_base: {d}\n seat: {d}\n output: {d}",
        .{ wl.compositor.name, wl.xdg_wm_base.name, wl.seat.name, wl.output.name },
    );

    try wl.conn.bindGlobal(
        WlCompositor,
        &wl.compositor,
        wl.registry_proxy.obj_id,
        consts.wl_compositor,
        wl,
        handlers.onCompositorEvent,
    );
    try wl.conn.bindGlobal(
        WlSeat,
        &wl.seat,
        wl.registry_proxy.obj_id,
        consts.wl_seat,
        wl,
        handlers.onSeatEvent,
    );
    try wl.conn.roundTrip();

    if (wl.has_keyboard) {
        log.trace(.platform, "Has keyboard", .{});
        wl.keyboard.proxy = try wl.conn.allocProxy(
            WlKeyboard,
            wl,
            handlers.onKeyboardEvent,
        );
        try wl.seat.proxy.send(wl.conn, WlSeat.Request{
            .get_keyboard = .{ .new_id = wl.keyboard.proxy.obj_id },
        });
        log.info(.platform, "Found KEYBOARD: {d}", .{wl.keyboard.proxy.obj_id});
    }
    if (wl.has_pointer) {
        wl.pointer.proxy = try wl.conn.allocProxy(
            WlPointer,
            wl,
            handlers.onPointerEvent,
        );
        try wl.seat.proxy.send(wl.conn, WlSeat.Request{
            .get_pointer = .{ .new_id = wl.pointer.proxy.obj_id },
        });
        log.info(.platform, "Found POINTER: {d}", .{wl.pointer.proxy.obj_id});
    }
    try wl.conn.roundTrip();

    try wl.conn.bindGlobal(
        XdgWmBase,
        &wl.xdg_wm_base,
        wl.registry_proxy.obj_id,
        consts.xdg_wm_base,
        wl,
        handlers.onXdgWmBaseEvent,
    );
    try wl.conn.roundTrip();

    try wl.conn.bindGlobal(
        WlOutput,
        &wl.output,
        wl.registry_proxy.obj_id,
        consts.wl_output,
        wl,
        handlers.onOutputEvent,
    );
    try wl.conn.roundTrip();
}
pub fn deinit() void {
    wl.compositor.proxy.send(wl.conn, WlCompositor.Request{ .release = .{} }) catch |e| {
        log.err(.platform, "Failed to destroy compositor {any}", .{e});
    };
    wl.seat.proxy.send(wl.conn, WlSeat.Request{ .release = .{} }) catch |e| {
        log.err(.platform, "Failed to destroy wl_seat {any}", .{e});
    };
    wl.output.proxy.send(wl.conn, WlOutput.Request{ .release = .{} }) catch |e| {
        log.err(.platform, "Failed to destroy wl_output {any}", .{e});
    };
    wl.xdg_wm_base.proxy.send(wl.conn, XdgWmBase.Request{ .release = .{} }) catch |e| {
        log.err(.platform, "Failed to destroy xdg_wm_base {any}", .{e});
    };

    wl.conn.deinit();
    gpa.destroy(wl);
}

pub const Window = struct {
    state: state.WindowState,
    width: u32 = 0,
    height: u32 = 0,
    should_close: bool = false,
    events: EventRingBuffer,

    pub fn deinit(self: *Window) void {
        self.state.xdg_toplevel.send(wl.conn, XdgToplevel.Request{ .destroy = .{} }) catch |e| {
            log.err(.platform, "Failed to destroy xdg_toplevel {any}", .{e});
        };
        self.state.xdg_surface.send(wl.conn, XdgSurface.Request{ .destroy = .{} }) catch |e| {
            log.err(.platform, "Failed to destroy xdg_surface {any}", .{e});
        };
        self.state.surface.send(wl.conn, WlSurface.Request{ .destroy = .{} }) catch |e| {
            log.err(.platform, "Failed to destroy wl_surface {any}", .{e});
        };

        wl.conn.unregisterProxy(self.state.xdg_toplevel.obj_id);
        wl.conn.unregisterProxy(self.state.xdg_surface.obj_id);
        wl.conn.unregisterProxy(self.state.surface.obj_id);

        gpa.free(self.events.data);
        gpa.destroy(self);
    }

    pub fn shouldClose(self: *const Window) bool {
        return self.should_close;
    }

    pub fn swapBuffers(self: *const Window, offset: u32) void {
        _ = self;
        _ = offset;
    }

    fn pushEvent(self: *Window, event: Event) void {
        self.events.push(event);
    }

    fn popEvent(self: *Window) ?Event {
        self.events.popFront();
    }
};

pub fn createWindow(config: WindowConfig) !*Window {
    const window = try gpa.create(Window);
    window.state = .{};

    window.state.surface = try wl.conn.allocProxy(
        WlSurface,
        &window.state,
        handlers.onSurfaceEvent,
    );
    try wl.compositor.proxy.send(
        wl.conn,
        WlCompositor.Request{ .create_surface = .{
            .new_id = window.state.surface.obj_id,
        } },
    );

    window.state.xdg_surface = try wl.conn.allocProxy(
        XdgSurface,
        &window.state,
        handlers.onXdgSurfaceEvent,
    );
    try wl.xdg_wm_base.proxy.send(
        wl.conn,
        XdgWmBase.Request{ .get_xdg_surface = .{
            .id = window.state.xdg_surface.obj_id,
            .surface = window.state.surface.obj_id,
        } },
    );

    window.state.xdg_toplevel = try wl.conn.allocProxy(
        XdgToplevel,
        &window.state,
        handlers.onXdgToplevelEvent,
    );
    try window.state.xdg_surface.send(
        wl.conn,
        XdgSurface.Request{ .get_toplevel = .{
            .id = window.state.xdg_toplevel.obj_id,
        } },
    );

    try window.state.xdg_toplevel.send(
        wl.conn,
        XdgToplevel.Request{ .set_title = .{
            .title = config.title,
        } },
    );

    try window.state.surface.send(
        wl.conn,
        WlSurface.Request{ .commit = .{} },
    );
    try wl.conn.roundTrip();

    try window.state.xdg_surface.send(
        wl.conn,
        XdgSurface.Request{ .ack_configure = .{
            .serial = window.state.configure_serial,
        } },
    );

    try window.state.surface.send(
        wl.conn,
        WlSurface.Request{ .commit = .{} },
    );

    window.width = config.width;
    window.height = config.height;
    window.events = try .init(gpa);

    return window;
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
    return @floatFromInt(wl.output_info.scale);
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

const EventRingBuffer = struct {
    alloc: Allocator,
    head: usize = 0,
    tail: usize = 0,
    max: usize = 64,
    data: []Event,

    pub fn init(alloc: Allocator) !EventRingBuffer {
        return .{
            .alloc = alloc,
            .data = try alloc.alloc(Event, 64),
        };
    }

    pub fn deinit(self: *EventRingBuffer) void {
        self.alloc.free(self.data);
    }

    pub fn push(self: *EventRingBuffer, e: Event) void {
        self.data[self.event_tail % 64] = e;
        self.tail += 1;
    }
    pub fn popFront(self: *EventRingBuffer) ?Event {
        if (self.head == self.tail) return null;
        const event = self.data[self.head % 64];
        self.head += 1;
        return event;
    }
};
