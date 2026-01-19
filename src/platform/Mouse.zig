const std = @import("std");
const Self = @This();
const core = @import("math");
const V2 = core.V2;
const id = @import("InputDevice.zig");
const InputDevice = id.InputDevice;

pub const MouseButton = enum(u8) {
    Left = 0,
    Right = 1,
    Middle = 2,
    Extra1 = 3,
    Extra2 = 4,

    Unused = 5,
};

pub const MouseData = struct {
    loc: V2,
    scroll_data: V2,
    button: MouseButton,
    is_down: bool,
};

buttons: InputDevice(MouseButton),
scroll_delta: V2 = .ZERO,
position: V2 = .ZERO,
location_delta: V2 = .ZERO,

pub fn update(self: *Self, data: MouseData) void {
    self.buttons.updateState(data.button, data.is_down);
    self.updateAnalogState(data.loc, data.scroll_data);
}

fn updateAnalogState(self: *Self, location: V2, scroll_delta: V2) void {
    self.location_delta = location.sub(self.position);
    self.position = location;
    self.scroll_delta = self.scroll_delta.add(scroll_delta);
}

pub fn clearState(self: *Self) void {
    self.scroll_delta = .ZERO;
    self.location_delta = .ZERO;
    self.buttons.clearFrameStates();
}
