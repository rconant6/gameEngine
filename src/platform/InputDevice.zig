const std = @import("std");
const builtin = @import("builtin");
const core = @import("math");
const V2 = core.V2;

pub const Keyboard = InputDevice(KeyCode);
pub const Mouse = @import("Mouse.zig");
pub const MouseButton = Mouse.MouseButton;
pub const MouseData = Mouse.MouseData;

pub const GamePad = struct {};

/// InputDevice is a state management machine
/// Tracks pressed, just_pressed, just_released for
/// the provided InputType ie. MouseButton, KeyCode, PadButton
pub fn InputDevice(comptime Device: type) type {
    const fields = @typeInfo(Device).@"enum".fields;

    comptime {
        for (fields, 0..) |field, i| {
            if (field.value != i)
                @compileError("Enum values must be contiguous starting from 0.");
        }
    }

    return struct {
        const Self = @This();
        const count = fields.len;

        pressed: [count]bool = @splat(false),
        just_pressed: [count]bool = @splat(false),
        just_released: [count]bool = @splat(false),

        pub fn isDown(self: *const Self, dev: Device) bool {
            return self.pressed[@intFromEnum(dev)];
        }
        pub fn isPressed(self: *const Self, dev: Device) bool {
            return self.just_pressed[@intFromEnum(dev)];
        }
        pub fn isReleased(self: *const Self, dev: Device) bool {
            return self.just_released[@intFromEnum(dev)];
        }

        pub fn updateState(self: *Self, dev: Device, down: bool) void {
            const idx = @intFromEnum(dev);
            const was_down = self.pressed[idx];

            if (down and !was_down) {
                self.just_pressed[idx] = true;
            } else if (!down and was_down) {
                self.just_released[idx] = true;
            }

            self.pressed[idx] = down;
        }

        pub fn clearFrameStates(self: *Self) void {
            @memset(&self.just_pressed, false);
            @memset(&self.just_released, false);
        }
    };
}
pub const KeyModifiers = packed struct {
    shift: bool = false,
    control: bool = false,
    alt: bool = false,
    super: bool = false, // Cmd on macOS, Win/Meta on Linux/Windows
    caps_lock: bool = false,
};

pub fn mapToGameMouseButton(button_num: u8) MouseButton {
    return switch (button_num) {
        0 => .Left,
        1 => .Right,
        2 => .Middle,
        3 => .Extra1,
        4 => .Extra2,
        else => .Unused,
    };
}

pub const KeyCode = enum(u8) {
    // Letters A-Z (0-25)
    A = 0,
    B = 1,
    C = 2,
    D = 3,
    E = 4,
    F = 5,
    G = 6,
    H = 7,
    I = 8,
    J = 9,
    K = 10,
    L = 11,
    M = 12,
    N = 13,
    O = 14,
    P = 15,
    Q = 16,
    R = 17,
    S = 18,
    T = 19,
    U = 20,
    V = 21,
    W = 22,
    X = 23,
    Y = 24,
    Z = 25,

    // Numbers 0-9 (26-35)
    Key0 = 26,
    Key1 = 27,
    Key2 = 28,
    Key3 = 29,
    Key4 = 30,
    Key5 = 31,
    Key6 = 32,
    Key7 = 33,
    Key8 = 34,
    Key9 = 35,

    // Arrow keys (36-39)
    Left = 36,
    Right = 37,
    Up = 38,
    Down = 39,

    // Function keys (40-51)
    F1 = 40,
    F2 = 41,
    F3 = 42,
    F4 = 43,
    F5 = 44,
    F6 = 45,
    F7 = 46,
    F8 = 47,
    F9 = 48,
    F10 = 49,
    F11 = 50,
    F12 = 51,

    // Special keys (52-57)
    Enter = 52,
    Space = 53,
    Esc = 54,
    Tab = 55,
    Backspace = 56,
    Delete = 57,

    // Modifier keys (58-65)
    LeftShift = 58,
    RightShift = 59,
    LeftCtrl = 60,
    RightCtrl = 61,
    LeftAlt = 62,
    RightAlt = 63,
    LeftSuper = 64, // Cmd on macOS, Win/Meta on Linux/Windows
    RightSuper = 65,

    // Punctuation (66-76)
    Semicolon = 66,
    Quote = 67,
    Comma = 68,
    Period = 69,
    Slash = 70,
    Grave = 71,
    Minus = 72,
    Equal = 73,
    LeftBracket = 74,
    RightBracket = 75,
    Backslash = 76,

    // Numpad (77-95)
    Numpad0 = 77,
    Numpad1 = 78,
    Numpad2 = 79,
    Numpad3 = 80,
    Numpad4 = 81,
    Numpad5 = 82,
    Numpad6 = 83,
    Numpad7 = 84,
    Numpad8 = 85,
    Numpad9 = 86,
    NumpadPlus = 87,
    NumpadMinus = 88,
    NumpadMultiply = 89,
    NumpadDivide = 90,
    NumpadEnter = 91,
    NumpadDecimal = 92,
    NumLock = 93,
    NumpadClear = 94,
    NumpadEqual = 95,

    // Unused (96)
    Unused = 96,
};

// Comptime validation: ensure enum is contiguous
comptime {
    const fields = @typeInfo(KeyCode).@"enum".fields;
    for (fields, 0..) |field, i| {
        if (field.value != i) {
            @compileError(std.fmt.comptimePrint(
                "KeyCode not contiguous: {s} has value {d}, expected {d}",
                .{ field.name, field.value, i },
            ));
        }
    }
}

pub fn mapToGameKeyCode(osKeyCode: u16) KeyCode {
    return switch (comptime builtin.os.tag) {
        .macos => switch (osKeyCode) {
            // Letters A-Z (macOS keycodes from NSEvent)
            0x00 => .A,
            0x0B => .B,
            0x08 => .C,
            0x02 => .D,
            0x0E => .E,
            0x03 => .F,
            0x05 => .G,
            0x04 => .H,
            0x22 => .I,
            0x26 => .J,
            0x28 => .K,
            0x25 => .L,
            0x2E => .M,
            0x2D => .N,
            0x1F => .O,
            0x23 => .P,
            0x0C => .Q,
            0x0F => .R,
            0x01 => .S,
            0x11 => .T,
            0x20 => .U,
            0x09 => .V,
            0x0D => .W,
            0x07 => .X,
            0x10 => .Y,
            0x06 => .Z,

            // Numbers 0-9 (macOS keycodes)
            0x1D => .Key0,
            0x12 => .Key1,
            0x13 => .Key2,
            0x14 => .Key3,
            0x15 => .Key4,
            0x17 => .Key5,
            0x16 => .Key6,
            0x1A => .Key7,
            0x1C => .Key8,
            0x19 => .Key9,

            // Arrow keys (macOS keycodes)
            0x7B => .Left,
            0x7C => .Right,
            0x7E => .Up,
            0x7D => .Down,

            // Function keys (macOS keycodes)
            0x7A => .F1,
            0x78 => .F2,
            0x63 => .F3,
            0x76 => .F4,
            0x60 => .F5,
            0x61 => .F6,
            0x62 => .F7,
            0x64 => .F8,
            0x65 => .F9,
            0x6D => .F10,
            0x67 => .F11,
            0x6F => .F12,

            // Special keys (macOS keycodes)
            0x24 => .Enter,
            0x31 => .Space,
            0x35 => .Esc,
            0x30 => .Tab,
            0x33 => .Backspace,
            0x75 => .Delete,

            // Modifier keys (macOS keycodes)
            0x38 => .LeftShift,
            0x3C => .RightShift,
            0x3B => .LeftCtrl,
            0x3E => .RightCtrl,
            0x3A => .LeftAlt,
            0x3D => .RightAlt,
            0x37 => .LeftSuper,
            0x36 => .RightSuper,

            // Punctuation (macOS keycodes)
            0x29 => .Semicolon,
            0x27 => .Quote,
            0x2B => .Comma,
            0x2F => .Period,
            0x2C => .Slash,
            0x32 => .Grave,
            0x1B => .Minus,
            0x18 => .Equal,
            0x21 => .LeftBracket,
            0x1E => .RightBracket,
            0x2A => .Backslash,

            // Number pad (macOS keycodes)
            0x52 => .Numpad0,
            0x53 => .Numpad1,
            0x54 => .Numpad2,
            0x55 => .Numpad3,
            0x56 => .Numpad4,
            0x57 => .Numpad5,
            0x58 => .Numpad6,
            0x59 => .Numpad7,
            0x5B => .Numpad8,
            0x5C => .Numpad9,
            0x45 => .NumpadPlus,
            0x4E => .NumpadMinus,
            0x43 => .NumpadMultiply,
            0x4B => .NumpadDivide,
            0x4C => .NumpadEnter,
            0x41 => .NumpadDecimal,
            0x47 => .NumpadClear,
            0x51 => .NumpadEqual,

            else => .Unused,
        },

        .windows => switch (osKeyCode) {
            // Letters A-Z
            0x41 => .A,
            0x42 => .B,
            0x43 => .C,
            0x44 => .D,
            0x45 => .E,
            0x46 => .F,
            0x47 => .G,
            0x48 => .H,
            0x49 => .I,
            0x4A => .J,
            0x4B => .K,
            0x4C => .L,
            0x4D => .M,
            0x4E => .N,
            0x4F => .O,
            0x50 => .P,
            0x51 => .Q,
            0x52 => .R,
            0x53 => .S,
            0x54 => .T,
            0x55 => .U,
            0x56 => .V,
            0x57 => .W,
            0x58 => .X,
            0x59 => .Y,
            0x5A => .Z,

            // Numbers 0-9
            0x30 => .Key0,
            0x31 => .Key1,
            0x32 => .Key2,
            0x33 => .Key3,
            0x34 => .Key4,
            0x35 => .Key5,
            0x36 => .Key6,
            0x37 => .Key7,
            0x38 => .Key8,
            0x39 => .Key9,

            // Arrow keys
            0x25 => .Left,
            0x27 => .Right,
            0x26 => .Up,
            0x28 => .Down,

            // Function keys
            0x70 => .F1,
            0x71 => .F2,
            0x72 => .F3,
            0x73 => .F4,
            0x74 => .F5,
            0x75 => .F6,
            0x76 => .F7,
            0x77 => .F8,
            0x78 => .F9,
            0x79 => .F10,
            0x7A => .F11,
            0x7B => .F12,

            // Special keys
            0x0D => .Enter,
            0x20 => .Space,
            0x1B => .Esc,
            0x09 => .Tab,
            0x08 => .Backspace,
            0x2E => .Delete,

            // Modifier keys
            0x10 => .LeftShift,
            0xA1 => .RightShift,
            0x11 => .LeftCtrl,
            0xA3 => .RightCtrl,
            0x12 => .LeftAlt,
            0xA5 => .RightAlt,
            0x5B => .LeftSuper,
            0x5C => .RightSuper,

            // Punctuation
            0xBA => .Semicolon,
            0xDE => .Quote,
            0xBC => .Comma,
            0xBE => .Period,
            0xBF => .Slash,
            0xC0 => .Grave,
            0xBD => .Minus,
            0xBB => .Equal,
            0xDB => .LeftBracket,
            0xDD => .RightBracket,
            0xDC => .Backslash,

            // Number pad
            0x60 => .Numpad0,
            0x61 => .Numpad1,
            0x62 => .Numpad2,
            0x63 => .Numpad3,
            0x64 => .Numpad4,
            0x65 => .Numpad5,
            0x66 => .Numpad6,
            0x67 => .Numpad7,
            0x68 => .Numpad8,
            0x69 => .Numpad9,
            0x6B => .NumpadPlus,
            0x6D => .NumpadMinus,
            0x6A => .NumpadMultiply,
            0x6F => .NumpadDivide,
            0x6E => .NumpadDecimal,
            0x90 => .NumLock,

            else => .Unused,
        },

        // Linux evdev keycodes — raw values from wl_keyboard.key (linux/input-event-codes.h)
        .linux => switch (osKeyCode) {
            // Letters
            30 => .A,
            48 => .B,
            46 => .C,
            32 => .D,
            18 => .E,
            33 => .F,
            34 => .G,
            35 => .H,
            23 => .I,
            36 => .J,
            37 => .K,
            38 => .L,
            50 => .M,
            49 => .N,
            24 => .O,
            25 => .P,
            16 => .Q,
            19 => .R,
            31 => .S,
            20 => .T,
            22 => .U,
            47 => .V,
            17 => .W,
            45 => .X,
            21 => .Y,
            44 => .Z,

            // Numbers 0-9 (top row)
            11 => .Key0,
            2 => .Key1,
            3 => .Key2,
            4 => .Key3,
            5 => .Key4,
            6 => .Key5,
            7 => .Key6,
            8 => .Key7,
            9 => .Key8,
            10 => .Key9,

            // Arrow keys
            105 => .Left,
            106 => .Right,
            103 => .Up,
            108 => .Down,

            // Function keys
            59 => .F1,
            60 => .F2,
            61 => .F3,
            62 => .F4,
            63 => .F5,
            64 => .F6,
            65 => .F7,
            66 => .F8,
            67 => .F9,
            68 => .F10,
            87 => .F11,
            88 => .F12,

            // Special keys
            28 => .Enter,
            57 => .Space,
            1 => .Esc,
            15 => .Tab,
            14 => .Backspace,
            111 => .Delete,

            // Modifier keys
            42 => .LeftShift,
            54 => .RightShift,
            29 => .LeftCtrl,
            97 => .RightCtrl,
            56 => .LeftAlt,
            100 => .RightAlt,
            125 => .LeftSuper,
            126 => .RightSuper,

            // Punctuation
            39 => .Semicolon,
            40 => .Quote,
            51 => .Comma,
            52 => .Period,
            53 => .Slash,
            41 => .Grave,
            12 => .Minus,
            13 => .Equal,
            26 => .LeftBracket,
            27 => .RightBracket,
            43 => .Backslash,

            // Numpad
            82 => .Numpad0,
            79 => .Numpad1,
            80 => .Numpad2,
            81 => .Numpad3,
            75 => .Numpad4,
            76 => .Numpad5,
            77 => .Numpad6,
            71 => .Numpad7,
            72 => .Numpad8,
            73 => .Numpad9,
            78 => .NumpadPlus,
            74 => .NumpadMinus,
            55 => .NumpadMultiply,
            98 => .NumpadDivide,
            96 => .NumpadEnter,
            83 => .NumpadDecimal,
            69 => .NumLock,

            else => .Unused,
        },

        else => .Unused,
    };
}
