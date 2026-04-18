const std = @import("std");
const ScreenPoint = @This();

x: f32,
y: f32,

pub fn add(self: ScreenPoint, other: ScreenPoint) ScreenPoint {
    return ScreenPoint{ .x = self.x + other.x, .y = self.y + other.y };
}

pub fn sub(self: ScreenPoint, other: ScreenPoint) ScreenPoint {
    return ScreenPoint{ .x = self.x - other.x, .y = self.y - other.y };
}

pub fn mul(self: ScreenPoint, scalar: f32) ScreenPoint {
    return ScreenPoint{ .x = self.x * scalar, .y = self.y * scalar };
}

pub fn div(self: ScreenPoint, scalar: f32) ScreenPoint {
    std.debug.assert(scalar != 0);
    return ScreenPoint{ .x = self.x / scalar, .y = self.y / scalar };
}

pub fn eql(self: ScreenPoint, other: ScreenPoint) bool {
    return self.x == other.x and self.y == other.y;
}

pub fn magnitude(self: ScreenPoint) f32 {
    return @sqrt(self.x * self.x + self.y * self.y);
}

pub fn normalize(self: ScreenPoint) ScreenPoint {
    const mag = self.magnitude();
    if (mag == 0) return ScreenPoint{ .x = 0, .y = 0 };
    return ScreenPoint{ .x = self.x / mag, .y = self.y / mag };
}

pub fn dot(self: ScreenPoint, other: ScreenPoint) f32 {
    return self.x * other.x + self.y * other.y;
}

/// Convert to integer coordinates for rasterization
pub fn toPixel(self: ScreenPoint) struct { x: i32, y: i32 } {
    return .{
        .x = @intFromFloat(self.x),
        .y = @intFromFloat(self.y),
    };
}
