const std = @import("std");
const Allocator = std.mem.Allocator;
const net = std.Io.net;
const wire = @import("linux/wayland/wire.zig");
const ObjIdAllocator = wire.ObjIdAllocator;
const WlFixed = wire.WlFixed;
const WlHeader = wire.Header;
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
const plat = @import("platform.zig");
const Capabilities = plat.Capabilities;
const DisplayInfo = plat.DisplayInfo;
const Event = plat.Event;
const KeyModifiers = plat.KeyModifiers;
const WindowConfig = plat.WindowConfig;
const V2I = @import("math").V2I;
const log = @import("debug").log;

var gpa: Allocator = undefined;
var conn: *WlConnection = undefined;
const display_id: u32 = 1; // always 1, set by protocol

const BoundGlobal = struct {
    name: u32 = 0,
    version: u32 = 0,
    obj_id: u32 = 0,
    interface: []const u8 = "",
};

var display_proxy: wire.Proxy(WlDisplay) = undefined;
var registry_proxy: wire.Proxy(WlRegistry) = undefined;
var compositor: BoundGlobal = .{};
var compositor_proxy: wire.Proxy(WlCompositor) = undefined;
var surface_id: u32 = 0;
var surface_proxy: wire.Proxy(WlSurface) = undefined;

var seat: BoundGlobal = .{};
var seat_proxy: wire.Proxy(WlSeat) = undefined;
var has_pointer: bool = false;
var pointer: BoundGlobal = .{};
var pointer_proxy: wire.Proxy(WlPointer) = undefined;
var has_keyboard: bool = false;
var keyboard: BoundGlobal = .{};
var keyboard_proxy: wire.Proxy(WlKeyboard) = undefined;
var output: BoundGlobal = .{};
var output_proxy: wire.Proxy(WlOutput) = undefined;
var output_width: i32 = 0;
var output_height: i32 = 0;
var output_refresh: i32 = 0;
var output_scale: i32 = 0;
// var has_touch: bool = false;

var xdg_wm_base: BoundGlobal = .{};
var xdg_wm_base_proxy: wire.Proxy(XdgWmBase) = undefined;
var xdg_surface: BoundGlobal = .{};
var xdg_surface_proxy: wire.Proxy(XdgSurface) = undefined;
var xdg_toplevel: BoundGlobal = .{};
var xdg_toplevel_proxy: wire.Proxy(XdgToplevel) = undefined;

var xdg_surface_serial: u32 = 0;

pub const Window = struct {
    surface_id: u32 = 0, // wl_surface
    xdg_surface_id: u32 = 0, // xdg_surface wrapper
    xdg_toplevel_id: u32 = 0, // xdg_toplevel (the actual window)
    configured: bool = false, // has compositor sent configure+ack?

    width: u32 = 0,
    height: u32 = 0,
    should_close: bool = false,

    event_head: usize = 0,
    event_tail: usize = 0,
    event_max: usize = 64,
    events: []Event,

    pub fn deinit(self: *Window) void {
        gpa.free(self.events);
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

pub fn createWindow(config: WindowConfig) !*Window {
    surface_id = conn.ids.alloc();
    try compositor_proxy.send(WlCompositor.Request{ .create_surface = .{
        .new_id = surface_id,
    } });
    surface_proxy = .{
        .obj_id = surface_id,
        .conn = conn,
        .on_event = onSurfaceEvent,
    };
    try conn.registerProxy(WlSurface, &surface_proxy);

    xdg_surface.obj_id = conn.ids.alloc();
    try xdg_wm_base_proxy.send(XdgWmBase.Request{ .get_xdg_surface = .{
        .id = xdg_surface.obj_id,
        .surface = surface_id,
    } });
    xdg_surface_proxy = .{
        .obj_id = xdg_surface.obj_id,
        .conn = conn,
        .on_event = onXdgSurfaceEvent,
    };
    try conn.registerProxy(XdgSurface, &xdg_surface_proxy);

    xdg_toplevel.obj_id = conn.ids.alloc();
    try xdg_surface_proxy.send(XdgSurface.Request{ .get_toplevel = .{
        .id = xdg_toplevel.obj_id,
    } });
    xdg_toplevel_proxy = .{
        .obj_id = xdg_toplevel.obj_id,
        .conn = conn,
        .on_event = onXdgToplevelEvent,
    };
    try conn.registerProxy(XdgToplevel, &xdg_toplevel_proxy);
    try xdg_toplevel_proxy.send(XdgToplevel.Request{ .set_title = .{
        .title = config.title,
    } });

    try surface_proxy.send(WlSurface.Request{ .commit = .{} });

    try conn.drain(xdg_surface.obj_id);

    try xdg_surface_proxy.send(XdgSurface.Request{ .ack_configure = .{
        .serial = xdg_surface_serial,
    } });

    try surface_proxy.send(WlSurface.Request{ .commit = .{} });

    const window = try gpa.create(Window);
    const events = try gpa.alloc(Event, 64);
    log.debug(.platform, "events len: {d}", .{events.len});
    window.* = .{
        .width = config.width,
        .height = config.height,
        .surface_id = surface_id,
        .xdg_surface_id = xdg_surface.obj_id,
        .xdg_toplevel_id = xdg_toplevel.obj_id,
        .events = events,
    };

    return window;
}

pub fn init(alloc: Allocator, io: std.Io, env: *std.process.Environ.Map) !void {
    gpa = alloc;
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

    const cb_id2 = conn.ids.alloc();
    try display_proxy.send(.{ .sync = .{ .callback = cb_id2 } });
    try conn.drain(cb_id2);

    if (has_keyboard) {
        keyboard.obj_id = conn.ids.alloc();
        try seat_proxy.send(.{ .get_keyboard = .{ .new_id = keyboard.obj_id } });
        keyboard_proxy = .{
            .obj_id = keyboard.obj_id,
            .conn = conn,
            .on_event = onKeyboardEvent,
        };
        try conn.registerProxy(WlKeyboard, &keyboard_proxy);

        log.info(.platform, "Wayland found a keyboard {d}", .{keyboard.obj_id});
    }
    if (has_pointer) {
        pointer.obj_id = conn.ids.alloc();
        try seat_proxy.send(.{ .get_pointer = .{ .new_id = pointer.obj_id } });
        pointer_proxy = .{
            .obj_id = pointer.obj_id,
            .conn = conn,
            .on_event = onPointerEvent,
        };
        try conn.registerProxy(WlPointer, &pointer_proxy);

        log.info(.platform, "Wayland found a pointer {d}", .{pointer.obj_id});
    }
    const cb_id3 = conn.ids.alloc();
    try display_proxy.send(.{ .sync = .{ .callback = cb_id3 } });
    try conn.drain(cb_id3);

    xdg_wm_base.obj_id = conn.ids.alloc();
    try registry_proxy.send(.{ .bind = .{
        .name = xdg_wm_base.name,
        .interface = xdg_wm_base.interface,
        .version = xdg_wm_base.version,
        .new_id = xdg_wm_base.obj_id,
    } });
    xdg_wm_base_proxy = .{
        .obj_id = xdg_wm_base.obj_id,
        .conn = conn,
        .on_event = onXdgWmBaseEvent,
    };
    try conn.registerProxy(XdgWmBase, &xdg_wm_base_proxy);
    log.info(.platform, "Bound xdg_wm_base: {d}", .{xdg_wm_base.obj_id});

    output.obj_id = conn.ids.alloc();
    try registry_proxy.send(.{ .bind = .{
        .name = output.name,
        .interface = output.interface,
        .version = output.version,
        .new_id = output.obj_id,
    } });
    output_proxy = .{
        .obj_id = output.obj_id,
        .conn = conn,
        .on_event = onOutputEvent,
    };
    try conn.registerProxy(WlOutput, &output_proxy);
    log.info(.platform, "Bound Output: {d}", .{output.obj_id});

    const cb_id4 = conn.ids.alloc();
    try display_proxy.send(.{ .sync = .{ .callback = cb_id4 } });
    try conn.drain(cb_id4);
}
pub fn deinit() void {
    compositor_proxy.send(.{
        .release = .{},
    }) catch |e| {
        log.err(.platform, "Unable to release the compositor: {any}", .{e});
    };
    conn.deinit();
}

fn onOutputEvent(event: WlOutput.Event) !void {
    switch (event) {
        .geometry => |g| {
            log.info(
                .platform,
                "output geometry: {d}x{d} mm, make={s} model={s}",
                .{ g.physical_width, g.physical_height, g.make, g.model },
            );
        },
        .mode => |m| {
            output_width = m.width;
            output_height = m.height;
            output_refresh = m.refresh;
            log.info(
                .platform,
                "output mode: {d}x{d} @ {d}mHz",
                .{ m.width, m.height, m.refresh },
            );
        },
        .scale => |s| {
            output_scale = s.scale;
            log.info(.platform, "output scale: {d}", .{output_scale});
        },
        .done => {},
        .name => |n| {
            log.info(.platform, "output name: {s}", .{n.name});
        },
        .description => |d| {
            log.info(.platform, "output description: {s}", .{d.desc});
        },
    }
}
fn onSurfaceEvent(event: WlSurface.Event) !void {
    switch (event) {
        else => {
            log.warn(.platform, "WlSurface Events are not handled", .{});
        },
    }
}

fn onXdgToplevelEvent(event: XdgToplevel.Event) !void {
    switch (event) {
        else => {
            log.warn(.platform, "XdgTopLevelEvents are not handled", .{});
        },
    }
}
fn onXdgSurfaceEvent(event: XdgSurface.Event) !void {
    switch (event) {
        .configure => |c| {
            log.trace(.platform, "XdgSurface CONFIG serial: {d}", .{c.serial});
            xdg_surface_serial = c.serial;
        },
    }
}
fn onXdgWmBaseEvent(event: XdgWmBase.Event) !void {
    switch (event) {
        .ping => |p| log.trace(.platform, "XdgBase PING serial: {d}", .{p.serial}),
    }
}

fn onKeyboardEvent(event: WlKeyboard.Event) !void {
    switch (event) {
        .enter => |ent| log.trace(.platform, "KB Enter event serial {d}, surf {d}", .{ ent.serial, ent.surface }),
        .leave => |l| log.trace(.platform, "KB Leave event serial {d} surf {d}", .{ l.serial, l.surface }),
        .keymap => |km| log.trace(.platform, "KB Keymap event format {d}", .{km.format}),
        .key => |k| log.trace(.platform, "KB Key event key {d}", .{k.key}),
        .modifiers => |mds| log.trace(.platform, "KB Modifiers event group {d}", .{mds.group}),
        .repeat_info => |ri| log.trace(.platform, "KB Repeat Info event rate {d}", .{ri.rate}),
    }
}
fn onPointerEvent(event: WlPointer.Event) !void {
    switch (event) {
        .enter => |ent| log.trace(.platform, "PTR enter event serial {d}, surf {d}", .{ ent.serial, ent.surface }),
        .leave => |l| log.trace(.platform, "PTR leave event serial {d} surf {d}", .{ l.serial, l.surface }),
        .button => |b| log.trace(.platform, "PTR event button {d}", .{b.button}),
        .frame => log.trace(.platform, "PTR frame event", .{}),
        else => |e| {
            log.warn(.platform, "PTR event not implemented: {any}", .{e});
        },
    }
}

fn onSeatEvent(event: WlSeat.Event) !void {
    switch (event) {
        .capabilities => |c| {
            log.info(.platform, "Seat capes: {d}", .{c.capes});
            has_pointer = (c.capes & WlSeatCape.pointer) != 0;
            has_keyboard = (c.capes & WlSeatCape.keyboard) != 0;
            // has_touch = (c.capes & SeatCap.touch) != 0;
        },
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
            } else if (std.mem.eql(u8, g.interface, "wl_output")) {
                xdg_wm_base.interface = "wl_output";
                xdg_wm_base.name = g.name;
                xdg_wm_base.version = g.version;
            }
        },
        .global_remove => {},
    }
}
fn onCompositorEvent(event: WlCompositor.Event) !void {
    switch (event) {}
    return;
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
