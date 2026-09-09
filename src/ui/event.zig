pub const EventKind = enum {
    mouse_move,
    mouse_down,
    mouse_up,
    mouse_scroll,
    key_down,
    text_input,
};

pub const MouseButton = enum { left, right, middle };
pub const KeyCode = enum {
    backspace,
    delete,
    left,
    right,
    home,
    end,
    enter,
    escape,
    tab,
};

pub const Event = struct {
    kind: EventKind,
    mouse_x: f32,
    mouse_y: f32,
    button: ?MouseButton,
    scroll_delta: f32 = 0,

    key: ?KeyCode = null,
    char: ?u21 = null,

    consumed: bool = false,

    pub fn consume(self: *Event) void {
        self.consumed = true;
    }
};
