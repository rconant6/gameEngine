const Engine = @import("engine.zig").Engine;
const math = @import("math");
const V2 = math.V2;

pub fn isDown(self: *const Engine, input: anytype) bool {
    return self.input.isDown(input);
}

pub fn isPressed(self: *const Engine, input: anytype) bool {
    return self.input.isPressed(input);
}

pub fn isReleased(self: *const Engine, input: anytype) bool {
    return self.input.isReleased(input);
}

pub fn getAxis(self: *const Engine, negative: anytype, positive: anytype) f32 {
    return self.input.getAxis(negative, positive);
}

pub fn getAxis2d(self: *const Engine, left: anytype, right: anytype, up: anytype, down: anytype) V2 {
    return self.input.getAxis2d(left, right, up, down);
}

pub fn getMouseScrollDelta(self: *const Engine) ?V2 {
    const delta = self.input.mouse.scroll_delta;
    return if (delta.x == 0 and delta.y == 0) null else delta;
}
