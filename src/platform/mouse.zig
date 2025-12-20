const std = @import("std");
const core = @import("core");
const V2 = core.V2;

const MAX_BUTTONS = 8;

pub const Mouse = struct {
    buttonsClicked: [MAX_BUTTONS]bool = .{false} ** MAX_BUTTONS,
    buttonsJustClicked: [MAX_BUTTONS]bool = .{false} ** MAX_BUTTONS,
    buttonsJustReleased: [MAX_BUTTONS]bool = .{false} ** MAX_BUTTONS,
};
