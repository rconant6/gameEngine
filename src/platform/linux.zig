const c = @cImport({
    @cInclude("wayland-client.h");
    @cInclude("xdg-shell-client-protocol.h");
});

const std = @import("std");
const Allocator = std.mem.Allocator;
const net = std.Io.net;

const plat = @import("platform.zig");
const Capabilities = plat.Capabilities;
const DisplayInfo = plat.DisplayInfo;
const Event = plat.Event;
const KeyModifiers = plat.KeyModifiers;
const WindowConfig = plat.WindowConfig;

const V2I = @import("math").V2I;
const log = @import("debug").log;

var gpa: Allocator = undefined;
var display: *c.wl_display = undefined;
var compositor: *c.wl_compositor = undefined;
var xdg_wm_base: *c.xdg_wm_base = undefined;
var seat: *c.wl_seat = undefined;
var output_scale: i32 = 1;
var registry: c.wl_registry_listener = .{
    .global = listenerGlobal,
    .global_remove = listenerGlobalRemove,
};

fn listenerGlobal(
    data: ?*anyopaque,
    wl_registry: ?*c.struct_wl_registry,
    name: u32,
    interface: [*c]const u8,
    version: u32,
) callconv(.c) void {
    _ = data;
    _ = wl_registry;
    _ = name;
    _ = interface;
    _ = version;
}
fn listenerGlobalRemove(
    data: ?*anyopaque,
    wl_registry: ?*c.struct_wl_registry,
    name: u32,
) callconv(.c) void {
    _ = data;
    _ = wl_registry;
    _ = name;
}

pub fn init(alloc: Allocator, io: std.Io, env: *std.process.Environ.Map) !void {
    _ = alloc;
    _ = io;
    _ = env;

    return error.NoLinuxInit;
    // return c.init();
}

pub fn deinit() void {}

const WindowHandle = struct {};

pub const Window = struct {
    handle: WindowHandle,
    // state: state.WindowState,
    width: u32 = 0,
    height: u32 = 0,
    should_close: bool = false,
    events: EventRingBuffer,

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
        self.events.push(event);
    }

    fn popEvent(self: *Window) ?Event {
        self.events.popFront();
    }
};

pub fn createWindow(config: WindowConfig) !*Window {
    _ = config;
    return error.WindowNotImplementedYet;
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

/// Caller of this will need to destroy the handles on their end
pub fn getNativeWindowHandle(window: *Window) *anyopaque {
    _ = window;
    return display;
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
