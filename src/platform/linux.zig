const std = @import("std");
const Allocator = std.mem.Allocator;
const plat = @import("platform.zig");

const Event = plat.Event;
const KeyModifiers = plat.KeyModifiers;
const WindowConfig = plat.WindowConfig;
const Capabilities = plat.Capabilities;
const DisplayInfo = plat.DisplayInfo;
const V2I = @import("math").V2I;

const WaylandMessage = packed struct {
    object_id: u32,
    size: u16,
    opcode: u16,
    args: []const u32,
};

fn sendMessage(state: *WaylandState, obj: u32, opcode: u16, args: []const u32) !void {
    _ = state;
    _ = obj;
    _ = opcode;
    _ = args;
}

const WaylandState = struct {
    socket: std.Io.net.Stream, // unix socket id
    send_buf: [4096]u8, // outgoing msg buffer
    recv_buf: [65536]u8, // incoming msg buffer
    recv_len: usize, // valid bytes in recv_buf

    display_id: u32 = 1, // always 1, set by protocol
    registry_id: u32, // get from the registry
    compositor_id: u32, // from the registry
    xdg_wm_base_id: u32, // from the registry
    seat_id: u32, // from teh registry
    keyboard_id: u32, // created from the seat
    pointer_id: u32, // created from the seat
    next_id: u32 = 2, // ID counter, starts at 2 (display = 1)
};

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

pub fn init(gpa: Allocator, env: *std.process.Environ.Map) !void {
    const runtime_dir = env.get("XDG_RUNTIME_DIR") orelse return error.NoRuntimeDir;
    const display_name = env.get("WAYLAND_DISPLAY") orelse "wayland-0";
    var path_buf: [128]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ runtime_dir, display_name });
    _ = path;
    _ = gpa;
    std.log.debug("path: {s}", .{path_buf});
}

pub fn deinit() void {}

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
