const std = @import("std");
const plat = @import("platform");
pub const Keyboard = plat.Keyboard;
pub const Mouse = plat.Mouse;
pub const KeyCode = plat.KeyCode;
pub const MouseButton = plat.MouseButton;

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

pub inline fn isPressed(self: *const Self, input: anytype) bool {
    const T = @TypeOf(input);
    validateSupportedType(T);

    if (T == KeyCode) return self.keyboard.isPressed(input);
    if (T == MouseButton) return self.mouse.isPressed(input);
    unreachable;
}
pub inline fn wasJustPressed(self: *const Self, input: anytype) bool {
    const T = @TypeOf(input);
    validateSupportedType(T);

    if (T == KeyCode) return self.keyboard.wasJustPressed(input);
    if (T == MouseButton) return self.mouse.wasJustPressed(input);
    unreachable;
}
pub inline fn wasJustReleased(self: *const Self, input: anytype) bool {
    const T = @TypeOf(input);
    validateSupportedType(T);

    if (T == KeyCode) return self.keyboard.wasJustReleased(input);
    if (T == MouseButton) return self.mouse.wasJustReleased(input);
    unreachable;
}
