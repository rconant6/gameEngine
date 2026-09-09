const V2 = @import("math").V2;

pub const EventKind = enum {
    mouse_move,
    mouse_down,
    mouse_up,
    mouse_scroll,
    key_down,
    text_input,
};

pub const MouseButton = enum { left, right, middle };

/// The keys the UI reacts to. Local to ui so it never imports platform;
/// `UIInput.fromDevices` maps them from whatever keyboard it is handed.
pub const KeyCode = enum {
    backspace,
    delete,
    left,
    right,
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

    pub fn mousePos(self: *const Event) V2 {
        return .{ .x = self.mouse_x, .y = self.mouse_y };
    }
};

/// (ui key, platform enum literal). The literal coerces to whatever enum
/// `kb.isPressed` takes, so ui never names the platform's KeyCode.
const key_map = .{
    .{ KeyCode.backspace, .Backspace },
    .{ KeyCode.delete, .Delete },
    .{ KeyCode.left, .Left },
    .{ KeyCode.right, .Right },
    .{ KeyCode.enter, .Enter },
    .{ KeyCode.escape, .Esc },
    .{ KeyCode.tab, .Tab },
};

/// One frame of input, by value. A new input kind adds a field here; call
/// sites that build it with `fromDevices` don't change.
pub const UIInput = struct {
    mouse_x: f32 = 0,
    mouse_y: f32 = 0,
    left_down: bool = false,
    left_up: bool = false,
    scroll_delta: f32 = 0,
    key_buf: [key_map.len]KeyCode = undefined, // valid in [0..key_len) only
    key_len: u8 = 0,
    text: []const u21 = &.{}, // borrowed from the platform's per-frame buffer

    /// Structural contract (anytype, like `ctx`):
    ///   mouse: .position.{x,y}, .buttons.isPressed(.Left), .buttons.isReleased(.Left), .scroll_delta.y
    ///   kb:    .isPressed(enum literal) bool
    pub fn fromDevices(mouse: anytype, kb: anytype, text: []const u21) UIInput {
        var in: UIInput = .{
            .mouse_x = mouse.position.x,
            .mouse_y = mouse.position.y,
            .left_down = mouse.buttons.isPressed(.Left),
            .left_up = mouse.buttons.isReleased(.Left),
            .scroll_delta = mouse.scroll_delta.y,
            .text = text,
        };
        inline for (key_map) |pair| {
            if (kb.isPressed(pair[1])) {
                in.key_buf[in.key_len] = pair[0];
                in.key_len += 1;
            }
        }
        return in;
    }

    pub fn keys(self: *const UIInput) []const KeyCode {
        return self.key_buf[0..self.key_len];
    }
};
