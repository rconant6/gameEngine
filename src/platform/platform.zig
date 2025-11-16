const std = @import("std");
const builtin = @import("builtin");

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

pub const Window = PlatformImpl.Window;

pub const WindowConfig = struct {
    title: []const u8,
    width: u32,
    height: u32,
    resizable: bool = true,
    vsync: bool = true,
    fullscreen: bool = false,
};
pub const KeyModifiers = packed struct {
    shift: bool = false,
    control: bool = false,
    alt: bool = false,
    caps_lock: bool = false,
};

pub const Key = enum(u16) {
    A,
    B,
    C,
    D,
    E,
    F,
    G,
    H,
    I,
    J,
    K,
    L,
    M,
    N,
    O,
    P,
    Q,
    R,
    S,
    T,
    U,
    V,
    W,
    X,
    Y,
    Z,

    pad0,
    pad1,
    pad2,
    pad3,
    pad4,
    pad5,
    pad6,
    pad7,
    pad8,
    pad9,

    Num0,
    Num1,
    Num2,
    Num3,
    Num4,
    Num5,
    Num6,
    Num7,
    Num8,
    Num9,

    F1,
    F2,
    F3,
    F4,
    F5,
    F6,
    F7,
    F8,
    F9,
    F10,
    F11,
    F12,

    Space,
    Enter,
    Escape,
    Tab,
    Backspace,
    Delete,
    Insert,

    Left,
    Right,
    Up,
    Down,

    LeftShift,
    RightShift,
    LeftControl,
    RightControl,
    LeftAlt,
    RightAlt,
    RightSuper,

    Home,
    End,
    PageUp,
    PageDown,

    Unknown,
};

pub const MouseButton = enum(u8) {
    Left,
    Right,
    Middle,
    Extra1,
    Extra2,
};

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
        key: Key,
        modifiers: KeyModifiers,
    },

    KeyRelease: struct {
        key: Key,
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

pub fn isKeyDown(window: *Window, key: Key) bool {
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

// pub const NativeHandles = PlatformImpl.NativeHandles;

// pub fn getNativeHandles(window: *Window) NativeHandles {
//     return PlatformImpl.getNativeHandles(window);
// }

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
