const std = @import("std");
const plat = @import("platform");
pub const Keyboard = plat.Keyboard;
pub const Mouse = plat.Mouse;
pub const KeyCode = plat.KeyCode;
pub const MouseButton = plat.MouseButton;
const core = @import("core");
const V2 = core.V2;

const Self = @This();

keyboard: *const Keyboard,
mouse: *const Mouse,

const SupportedInputTypes = .{ KeyCode, MouseButton };

pub fn init() Self {
    return .{
        .keyboard = plat.getKeyboard(),
        .mouse = plat.getMouse(),
    };
}

fn validateSupportedType(comptime T: type) void {
    inline for (SupportedInputTypes) |SupportedType| {
        if (T == SupportedType) return;
    }
    @compileError("Input type " ++ @typeName(T) ++ " not handled in Input");
}

pub inline fn isDown(self: *const Self, input: anytype) bool {
    const T = @TypeOf(input);
    validateSupportedType(T);

    if (T == KeyCode) return self.keyboard.isDown(input);
    if (T == MouseButton) return self.mouse.isDown(input);
    unreachable;
}
pub inline fn isPressed(self: *const Self, input: anytype) bool {
    const T = @TypeOf(input);
    validateSupportedType(T);

    if (T == KeyCode) return self.keyboard.isPressed(input);
    if (T == MouseButton) return self.mouse.isPressed(input);
    unreachable;
}
pub inline fn isReleased(self: *const Self, input: anytype) bool {
    const T = @TypeOf(input);
    validateSupportedType(T);

    if (T == KeyCode) return self.keyboard.isReleased(input);
    if (T == MouseButton) return self.mouse.isReleased(input);
    unreachable;
}

pub fn getAxis(self: *const Self, negative: anytype, positive: anytype) f32 {
    if (self.isDown(negative)) return -1.0;
    if (self.isDown(positive)) return 1.0;
    return 0.0;
}
pub fn getAxis2d(self: *const Self, left: anytype, right: anytype, up: anytype, down: anytype) V2 {
    const vec: V2 = .{
        .x = self.getAxis(left, right),
        .y = self.getAxis(up, down),
    };
    const len = vec.magnitude();
    if (len > 0.0) return vec.mul(1.0 / len);
    return vec;
}
