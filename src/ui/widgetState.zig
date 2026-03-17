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

    flags: u16,
    value: struct { val: f16, flags: u16 = 0 },
};
