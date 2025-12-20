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
const PlatformImpl = plat.PlatformImpl;
const WindowConfig = plat.WindowConfig;
const Keyboard = plat.Keyboard;
const Mouse = plat.Mouse;

var keyboard_state: Keyboard = .{};
var mouse_state: Mouse = .{};

pub const Window = struct {
    handle: c.WindowHandle,

    pub fn deinit(self: *Window) void {
        c.destroy_window(self.handle);
    }

    pub fn shouldClose(self: *const Window) bool {
        return c.window_should_close(self.handle);
    }

    pub fn swapBuffers(self: *const Window, offset: u32) void {
        c.swap_buffers(self.handle, offset);
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
        pixels.len,
        @intCast(width),
        @intCast(height),
    );
}

pub fn pollEvent() ?Event {
    _ = c.poll_events(); // process macos events

    var keycode: u16 = undefined;
    var is_down: u8 = undefined;

    while (poll_key_event(&keycode, &is_down)) {
        const key = plat.mapToGameKeyCode(keycode);
        if (key == .Unused) {
            std.log.warn("[INPUT] Unknown macOS keycode 0x{X:0>2}", .{keycode});
            continue;
        }
        keyboard_state.updateState(key, is_down != 0);
    }

    return null;
}
pub fn waitEvent() Event {
    return .NullEvent;
}

pub fn getNativeWindowHandle(window: *Window) *anyopaque {
    return window.handle;
}

pub fn getMetalLayer(window: *Window) ?*anyopaque {
    return c.get_metal_layer(window.handle);
}

pub fn getWindowScaleFactor(window: *Window) f32 {
    return c.get_window_scale_factor(window.handle);
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

pub fn getKeyboard() *Keyboard {
    return &keyboard_state;
}
pub fn getMouse() *Mouse {
    return &mouse_state;
}

pub fn clearInputFrameStates() void {
    keyboard_state.clearFrameStates();
    mouse_state.clearFrameStates();
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
