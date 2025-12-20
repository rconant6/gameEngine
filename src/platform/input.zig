const kb = @import("keyboard.zig");
const Keyboard = kb.Keyboard;
const KeyCode = kb.KeyCode;
const m = @import("mouse.zig");
const Mouse = m.Mouse;

pub const Input = struct {
    keyboard: Keyboard,
    mouse: Mouse,
};
