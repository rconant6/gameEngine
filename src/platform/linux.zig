const std = @import("std");
const plat = @import("platform.zig");

const Event = plat.Event;
const KeyModifiers = plat.KeyModifiers;
const WindowConfig = plat.WindowConfig;
const Capabilities = plat.Capabilities;
const DisplayInfo = plat.DisplayInfo;
const V2I = @import("math").V2I;

pub const Window = struct {
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

pub fn init() !void {}
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
