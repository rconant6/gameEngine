const std = @import("std");
// INFO: Remeber the c.calls are for the swift bridge,
// this won't need to be duplicated in windows/linux.zig
const c = @cImport({
    @cInclude("macos_bridge.h");
});
const plat = @import("platform.zig");
const Capabilities = plat.Capabilities;
const DisplayInfo = plat.DisplayInfo;
const Event = plat.Event;
const Key = plat.Key;
const KeyModifiers = plat.KeyModifiers;
const MouseButton = plat.MouseButton;
const WindowConfig = plat.WindowConfig;

// TODO: MacOS keymapping map?

pub const Window = struct {
    handle: c.WindowHandle,

    pub fn deinit(self: *Window) void {
        c.destroy_window(self.handle);
    }

    pub fn shouldClose(self: *const Window) bool {
        return c.window_should_close(self.handle);
    }

    pub fn swapBuffers(self: *Window) void {
        c.swap_buffers(self.handle);
    }
};

pub fn init() !void {
    c.init();
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

    if (handle == null) {
        return error.WindowCreationFailed;
    }

    const window = try std.heap.c_allocator.create(Window);
    window.* = Window{ .handle = handle };

    return window;
}

pub fn setPixelBuffer(window: *Window, pixels: []const u8, width: u32, height: u32) void {
    set_pixel_buffer(
        window.handle,
        pixels.ptr,
        @intCast(width),
        @intCast(height),
    );
}

pub fn pollEvent() ?Event {
    _ = c.poll_events();
    return null;
}
pub fn waitEvent() Event {
    return .NullEvent;
}

pub fn isKeyDown(window: *Window, key: Key) bool {
    _ = window;
    _ = key;
    return false;
}

pub fn getMousePosition(window: *Window) struct { x: i32, y: i32 } {
    _ = window;
    return .{ .x = 0, .y = 0 };
}

pub fn isMouseButtonDown(window: *Window, button: MouseButton) bool {
    _ = window;
    _ = button;
    return false;
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
    return 0;
}

pub fn sleep(seconds: f64) void {
    _ = seconds;
}

pub fn getNativeWindowHandle(window: *Window) *anyopaque {
    return window.handle;
}

// pub fn getNativeHandles(window: *Window) NativeHandles {
//     return PlatformImpl.getNativeHandles(window);
// }

pub fn getDisplays(allocator: std.mem.Allocator) ![]DisplayInfo {
    _ = allocator;
    return std.Error.NotImplemented;
}

pub fn getWindowScaleFactor(window: *Window) f32 {
    return c.get_window_scale_factor(window.handle);
}

pub fn getClipboardText(allocator: std.mem.Allocator) ![]const u8 {
    _ = allocator;
    return "TODO: This is not implemented\n";
}

pub fn setClipboardText(text: []const u8) !void {
    _ = text;
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

pub fn openFileDialog(
    allocator: std.mem.Allocator,
    title: []const u8,
    filters: []const []const u8,
) ?[]const u8 {
    _ = allocator;
    _ = filters;
    _ = title;
    return null;
}

pub fn saveFileDialog(
    allocator: std.mem.Allocator,
    title: []const u8,
    default_name: []const u8,
) ?[]const u8 {
    _ = allocator;
    _ = default_name;
    _ = title;
    return null;
}

extern fn set_pixel_buffer(
    window: c.WindowHandle,
    pixels: [*]const u8,
    width: i32,
    height: i32,
) void;
