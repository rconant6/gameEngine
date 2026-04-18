pub const EventKind = enum {
    mouse_move,
    mouse_down,
    mouse_up,
};

pub const MouseButton = enum { left, right, middle };

pub const Event = struct {
    kind: EventKind,
    mouse_x: f32,
    mouse_y: f32,
    button: ?MouseButton,
    consumed: bool = false,

    pub fn consume(self: *Event) void {
        self.consumed = true;
    }
};
