const std = @import("std");
const builtin = @import("builtin");
const id = @import("InputDevice.zig");
pub const InputDevice = id.InputDevice;
pub const Keyboard = id.Keyboard;
pub const KeyCode = id.KeyCode;
pub const KeyModifiers = id.KeyModifiers;
pub const Mouse = id.Mouse;
pub const MouseButton = id.MouseButton;
pub const MouseData = id.MouseData;
pub const Window = PlatformImpl.Window;
// Internal use only - used by platform implementations
pub const mapToGameKeyCode = id.mapToGameKeyCode;
pub const mapToGameMouseButton = id.mapToGameMouseButton;

// Input system
pub const Input = @import("Input.zig");

const PlatformImpl = switch (builtin.os.tag) {
    .macos => @import("macos.zig"),
    .linux => @import("linux.zig"),
    .windows => @import("windows.zig"),
    else => @compileError("Unsupported platform: " ++ @tagName(builtin.os.tag)),
};

pub const Capabilities = struct {
    has_vulkan: bool,
    has_opengl: bool,
    has_metal: bool,
    has_file_dialogs: bool,
    has_clipboard: bool,
};

pub const DisplayInfo = struct {
    name: []const u8,
    width: u32,
    height: u32,
    refresh_rate: u32,
    is_primary: bool,
};

pub const WindowConfig = struct {
    title: []const u8,
    width: u32,
    height: u32,
    resizable: bool = false,
    vsync: bool = true,
    fullscreen: bool = false,
};

pub fn getKeyboard() *const Keyboard {
    return PlatformImpl.getKeyboard();
}
pub fn getMouse() *const Mouse {
    return PlatformImpl.getMouse();
}
pub fn clearInputStates() void {
    PlatformImpl.clearInputFrameStates();
}

pub const Event = union(enum) {
    NullEvent,
    WindowClose,
    WindowFocusGained,
    WindowFocusLost,

    WindowResize: struct {
        width: u32,
        height: u32,
    },

    KeyPress: struct {
        key: KeyCode,
        modifiers: KeyModifiers,
    },

    KeyRelease: struct {
        key: KeyCode,
        modifiers: KeyModifiers,
    },

    TextInput: struct {
        codepoint: u21,
    },

    MouseButtonPress: struct {
        button: MouseButton,
        x: i32,
        y: i32,
    },

    MouseButtonRelease: struct {
        button: MouseButton,
        x: i32,
        y: i32,
    },

    MouseMove: struct {
        x: i32,
        y: i32,
        delta_x: i32,
        delta_y: i32,
    },

    MouseWheel: struct {
        delta_x: f32,
        delta_y: f32,
    },
};

pub fn init() !void {
    return PlatformImpl.init();
}
pub fn deinit() void {
    PlatformImpl.deinit();
}
pub fn createWindow(config: WindowConfig) !*Window {
    return try PlatformImpl.createWindow(config);
}
pub fn setPixelBuffer(window: *Window, pixels: []const u8, width: u32, height: u32) void {
    PlatformImpl.setPixelBuffer(window, pixels, width, height);
}
pub fn swapBuffers(window: *Window, offset: u32) void {
    PlatformImpl.swapBuffers(window, offset);
}

pub fn pollEvent() ?Event {
    return PlatformImpl.pollEvent();
}
pub fn waitEvent() Event {
    return PlatformImpl.waitEvent();
}

pub fn isKeyDown(window: *Window, key: KeyCode) bool {
    return PlatformImpl.isKeyDown(window, key);
}

pub fn getMousePosition(window: *Window) struct { x: i32, y: i32 } {
    return PlatformImpl.getMousePosition(window);
}

pub fn isMouseButtonDown(window: *Window, button: MouseButton) bool {
    return PlatformImpl.isMouseButtonDown(window, button);
}

pub fn setMouseCursorVisible(window: *Window, visible: bool) void {
    PlatformImpl.setMouseCursorVisible(window, visible);
}

pub fn setMouseCursorLocked(window: *Window, locked: bool) void {
    PlatformImpl.setMouseCursorLocked(window, locked);
}

pub fn getTime() f64 {
    return PlatformImpl.getTime();
}

pub fn sleep(seconds: f64) void {
    PlatformImpl.sleep(seconds);
}

pub fn getNativeWindowHandle(window: *Window) *anyopaque {
    return PlatformImpl.getNativeWindowHandle(window);
}

pub fn getDisplays(allocator: std.mem.Allocator) ![]DisplayInfo {
    return PlatformImpl.getDisplays(allocator);
}

pub fn getWindowScaleFactor(window: *Window) f32 {
    return PlatformImpl.getWindowScaleFactor(window);
}

pub fn getClipboardText(allocator: std.mem.Allocator) ![]const u8 {
    return PlatformImpl.getClipboardText(allocator);
}

pub fn setClipboardText(text: []const u8) !void {
    return PlatformImpl.setClipboardText(text);
}

pub fn openFileDialog(allocator: std.mem.Allocator, title: []const u8, filters: []const []const u8) ?[]const u8 {
    if (@hasDecl(PlatformImpl, "openFileDialog")) {
        return PlatformImpl.openFileDialog(allocator, title, filters);
    }
    return null;
}

pub fn saveFileDialog(allocator: std.mem.Allocator, title: []const u8, default_name: []const u8) ?[]const u8 {
    if (@hasDecl(PlatformImpl, "saveFileDialog")) {
        return PlatformImpl.saveFileDialog(allocator, title, default_name);
    }
    return null;
}

pub fn getCapabilities() Capabilities {
    return PlatformImpl.getCapabilities();
}

pub fn getPlatformName() []const u8 {
    return switch (builtin.os.tag) {
        .macos => "macOS",
        .linux => "Linux",
        .windows => "Windows",
        else => "Unknown",
    };
}
