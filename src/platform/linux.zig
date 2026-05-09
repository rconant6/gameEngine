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
const WLDisplay = faces.WlDisplay;
const WlRegistry = faces.WlRegistry;
const Event = plat.Event;
const KeyModifiers = plat.KeyModifiers;
const WindowConfig = plat.WindowConfig;
const Capabilities = plat.Capabilities;
const DisplayInfo = plat.DisplayInfo;
const V2I = @import("math").V2I;
const log = @import("debug").log;

// const WaylandState = struct {
// stream: std.Io.net.Stream = undefined, // unix socket id
// send_buf: [4096]u8 = undefined, // outgoing msg buffer
// recv_buf: [65536]u8 = undefined, // incoming msg buffer
// recv_len: usize = 0, // valid bytes in recv_buf

// display_id: u32 = 1, // always 1, set by protocol
// registry_id: u32 = 0, // get from the registry
//     compositor_id: u32 = 0, // from the registry
//     xdg_wm_base_id: u32 = 0, // from the registry
//     seat_id: u32 = 0, // from teh registry
//     keyboard_id: u32 = 0, // created from the seat
//     pointer_id: u32 = 0, // created from the seat
//     ids: wlp.ObjIdAllocator = .{}, // ID counter, starts at 2 (display = 1)
// };

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
var display_id: u32 = 1; // always 1, set by protocol
var registry_id: u32 = 0; // get from the registry

pub fn init(gpa: Allocator, io: std.Io, env: *std.process.Environ.Map) !void {
    conn = try WlConnection.init(gpa, io, env);
    registry_id = conn.ids.alloc(); // Protocol gives next available

    try conn.sendRaw(display_id, WLDisplay.Request{ .get_registry = .{ .registry = registry_id } });

    try drain(0);
}

fn drain(stop_obj_id: u32) !void {
    while (true) {
        const m = try conn.nextMessage();
        dispatch(m.header.obj_id, m.header.opcode(), m.bytes);
        if (m.header.obj_id == stop_obj_id) return;
    }
}

fn dispatch(obj_id: u32, opcode: u16, payload: []const u8) void {
    if (obj_id == 1) {
        switch (opcode) {
            0 => {
                const T = std.meta.fields(WLDisplay.Event)[@intFromEnum(WLDisplay.Event.err)].type;
                const msg = try wire.parse(T, payload);
                log.err(.platform, "display error: {any}", .{msg});
            },
            else => {},
        }
    } else if (obj_id == registry_id) {
        switch (opcode) {
            0 => {
                const T = std.meta.fields(WlRegistry.Event)[@intFromEnum(WlRegistry.Event.global)].type;
                const msg = try wire.parse(T, payload);
                std.debug.print("{any}\n", .{msg});
            },
            else => log.debug(.platform, "Not implemented: registry_id", .{}),
        }
    } else {
        log.warn(.platform, "dispatch missed", .{});
    }
}

pub fn deinit() void {
    conn.deinit();
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
