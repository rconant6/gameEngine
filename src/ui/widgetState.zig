/// Internal storage for states of widgets.
/// Widgets declare `pub const state_kind = .flags` or `.value`
/// to indicate which variant they need.
///
/// flags: bit-maskable boolean states (hovered, pressed, checked, disabled, etc.)
/// value: continuous state (slider position, scroll offset) + flags for interaction
pub const WidgetState = union(enum) {
    pub const hovered: u16 = 0x1;
    pub const pressed: u16 = 0x2;
    pub const selected: u16 = 0x4;
    pub const dragging: u16 = 0x8;
    pub const focused: u16 = 0x10;

    flags: u16,
    value: struct { val: f16, flags: u16 = 0 },

    cursor: struct {
        offset: f32 = 0, // Scrollview: scroll px
        index: u32 = 0, // TextInput: caret pos
        flags: u16 = 0,
    },
};
