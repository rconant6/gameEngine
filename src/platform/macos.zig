const std = @import("std");
// INFO: c.calls are for the swift bridge; not duplicated in windows/linux.zig
const c = @cImport({
    @cInclude("macos_bridge.h");
});
const plat = @import("platform.zig");
const Capabilities = plat.Capabilities;
const DisplayInfo = plat.DisplayInfo;
const Event = plat.Event;
const KeyModifiers = plat.KeyModifiers;
const MouseButton = plat.MouseButton;
const WindowConfig = plat.WindowConfig;
const V2I = @import("math").V2I;

// macOS uses bottom-left origin; platform contract is top-left.
var window_height: f32 = 0;
// Key events are dequeued one at a time across pollNextEvent calls.
// We drain the OS queue once per frame via _pumpOS, then yield events one by one.
var os_pumped: bool = false;

pub const Window = struct {
    _handle: c.WindowHandle,

    pub fn deinit(self: *Window) void {
        c.destroy_window(self._handle);
    }

    pub fn shouldClose(self: *const Window) bool {
        return c.window_should_close(self._handle);
    }

    pub fn swapBuffers(self: *const Window, offset: u32) void {
        c.swap_buffers(self._handle, offset);
    }
};

pub fn init() !void {
    return c.init();
}
pub fn deinit() void {
    c.deinit();
}

pub fn createWindow(options: WindowConfig) !*Window {
    const handle = c.create_window(
        @intCast(options.width),
        @intCast(options.height),
        options.title.ptr,
    );
    if (handle == null) return error.WindowCreationFailed;

    const window = try std.heap.c_allocator.create(Window);
    window.* = Window{ ._handle = handle };
    window_height = @floatFromInt(options.height);
    return window;
}

pub fn setPixelBuffer(window: *Window, pixels: []const u8, width: u32, height: u32) void {
    set_pixel_buffer(
        window._handle,
        pixels.ptr,
        pixels.len,
        @intCast(width),
        @intCast(height),
    );
}

// Returns one abstract Event per call.  Returns null when the OS queue is empty.
// platform.zig calls this in a loop, feeding each event into the shared state machine.
pub fn pollNextEvent() ?Event {
    // Pump the OS event queue once per poll cycle (first call resets the flag).
    if (!os_pumped) {
        _ = c.poll_events();
        os_pumped = true;
    }

    var keycode: u16 = undefined;
    var is_down: u8 = undefined;
    while (poll_key_event(&keycode, &is_down)) {
        const key = plat.mapToGameKeyCode(keycode);
        if (key == .Unused) continue;
        if (is_down != 0) {
            return .{ .KeyPress = .{ .key = key, .modifiers = .{} } };
        } else {
            return .{ .KeyRelease = .{ .key = key, .modifiers = .{} } };
        }
    }

    var x: f32 = undefined;
    var y: f32 = undefined;
    var scroll_x: f32 = 0;
    var scroll_y: f32 = 0;
    var button: u8 = undefined;
    var m_down: u8 = undefined;
    if (poll_mouse_event(&x, &y, &scroll_x, &scroll_y, &button, &m_down)) {
        const flipped_y = window_height - y - 1;
        const xi: i32 = @intFromFloat(x);
        const yi: i32 = @intFromFloat(flipped_y);
        // 0xFF sentinel means move or scroll — no button involved.
        if (button == 0xFF) {
            if (scroll_x != 0 or scroll_y != 0) {
                return .{ .MouseWheel = .{ .delta_x = scroll_x, .delta_y = scroll_y } };
            }
            return .{ .MouseMove = .{ .x = xi, .y = yi, .delta_x = 0, .delta_y = 0 } };
        }
        const b = plat.mapToGameMouseButton(button);
        if (b == .Unused) return pollNextEvent(); // unknown button, skip
        if (m_down != 0) {
            return .{ .MouseButtonPress = .{ .button = b, .x = xi, .y = yi } };
        } else {
            return .{ .MouseButtonRelease = .{ .button = b, .x = xi, .y = yi } };
        }
    }

    // Queue exhausted — reset pump flag for next frame.
    os_pumped = false;
    return null;
}

pub fn waitEvent() Event {
    return .NullEvent;
}

pub fn getNativeWindowHandle(window: *Window) *anyopaque {
    return window._handle.?;
}

pub fn getMetalLayer(window: *Window) ?*anyopaque {
    return c.get_metal_layer(window._handle);
}

pub fn getWindowScaleFactor(window: *Window) f32 {
    return c.get_window_scale_factor(window._handle);
}

pub fn getCapabilities() Capabilities {
    return .{
        .has_clipboard = true,
        .has_file_dialogs = true,
        .has_metal = true,
        .has_opengl = false,
        .has_vulkan = false,
    };
}

pub fn getMousePosition(window: *Window) V2I {
    _ = window;
    // platform.zig tracks mouse position in the shared state.
    unreachable;
}

extern fn set_pixel_buffer(
    window: c.WindowHandle,
    pixels: [*]const u8,
    buffer_length: usize,
    width: i32,
    height: i32,
) void;

extern fn swap_buffers(window: c.WindowHandle, offset: usize) void;
extern fn poll_key_event(keycode: *u16, is_down: *u8) bool;
extern fn poll_mouse_event(x: *f32, y: *f32, scroll_x: *f32, scroll_y: *f32, button: *u8, isDown: *u8) bool;
