const std = @import("std");
const Allocator = std.mem.Allocator;
const plat = @import("platform.zig");
const Capabilities = plat.Capabilities;
const DisplayInfo = plat.DisplayInfo;
const Event = plat.Event;
const KeyModifiers = plat.KeyModifiers;
const WindowConfig = plat.WindowConfig;
const V2I = @import("math").V2I;
const log = @import("debug").log;
const wl = @import("linux/wayland/listeners.zig");
const c = wl.c;
const WaylandState = wl.WaylandState;

var gpa: Allocator = undefined;
var state: *WaylandState = undefined;

pub fn init(alloc: Allocator, io: std.Io, env: *std.process.Environ.Map) !void {
    gpa = alloc;
    _ = io;
    _ = env;

    state = try gpa.create(WaylandState);
    state.* = .{};

    state.display = c.wl_display_connect(null) orelse
        return error.WaylandConnectionFailed;
    state.registry = c.wl_display_get_registry(state.display) orelse
        return error.WaylandRegistryFailed;

    _ = c.wl_registry_add_listener(
        state.registry,
        &wl.RegistryListener,
        state,
    );

    // fires the globals, binds xdg_wm_base, seat
    _ = c.wl_display_roundtrip(state.display);
    // gets the seat capabilities (2)
    _ = c.wl_display_roundtrip(state.display);

    return;
}

pub fn deinit() void {
    // TODO: break down in the reverse order we made it
}

const WindowHandle = struct {
    display: *anyopaque,
    surface: *anyopaque,
};

pub const Window = struct {
    surface: *c.wl_surface,
    xdg_surface: *c.xdg_surface,
    xdg_toplevel: *c.xdg_toplevel,
    configured: bool = false,
    should_close: bool = false,
    width: u32 = 640,
    height: u32 = 480,
    events: EventRingBuffer,
    handle: *WindowHandle,

    pub fn deinit(self: *Window) void {
        self.events.deinit();
        gpa.destroy(self.handle);
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
    const surface = c.wl_compositor_create_surface(state.compositor) orelse
        return error.UnableToCreateWLSurface;
    const xdg_surface = c.xdg_wm_base_get_xdg_surface(state.xdg_wm_base, surface) orelse
        return error.UnableToCreateXDGSurface;
    // add a xdg_surface_listener
    const xdg_toplevel = c.xdg_surface_get_toplevel(xdg_surface) orelse
        return error.UnableToGetXDGTopLevel;
    // add a toplevel listener
    c.xdg_toplevel_set_title(xdg_toplevel, @ptrCast(config.title));
    c.wl_surface_commit(surface);
    _ = c.wl_display_roundtrip(state.display);

    const wh = gpa.create(WindowHandle) catch |err| {
        log.err(.platform, "Unable to get window handle {t}", .{err});
        return undefined;
    };
    wh.* =
        WindowHandle{
            .display = @ptrCast(@alignCast(state.display)),
            .surface = @ptrCast(@alignCast(surface)),
        };

    const window = try gpa.create(Window);
    window.* = .{
        .handle = wh,
        .surface = surface,
        .xdg_surface = xdg_surface,
        .xdg_toplevel = xdg_toplevel,
        .events = try .init(gpa),
        .width = config.width,
        .height = config.height,
    };

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

// pub fn getTime() f64 {
//     return @floatFromInt(std.time.milliTimestamp());
// }

// pub fn sleep(seconds: f64) void {
//     std.time.sleep(@intFromFloat(seconds * std.time.ns_per_s));
// }

/// Caller of this will need to destroy the handles on their end
pub fn getNativeWindowHandle(window: *Window) *anyopaque {
    const wh = gpa.create(WindowHandle) catch |err| {
        log.err(.platform, "Unable to get window handle {t}", .{err});
        return undefined;
    };
    wh.* =
        WindowHandle{
            .display = @ptrCast(@alignCast(state.display)),
            .surface = @ptrCast(@alignCast(window.surface)),
        };
    // return @as(*anyopaque, wh);
    return wh;
}

pub fn getWindowScaleFactor(window: *Window) f32 {
    // return c.wl_output_add_listener(state.output, &output_listener, null);
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
