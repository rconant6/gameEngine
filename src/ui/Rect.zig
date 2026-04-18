const std = @import("std");
const math = @import("math");
const V2 = math.V2;
const ScreenPoint = math.ScreenPoint;
const Self = @This();

pub const zero: Self = .{ .x = 0, .y = 0, .width = 0, .height = 0 };

x: f32,
y: f32,
width: f32,
height: f32,

pub fn fromTopLeft(
    x: f32,
    y: f32,
    w: f32,
    h: f32,
) Self {
    return .{
        .x = x,
        .y = y,
        .width = w,
        .height = h,
    };
}

pub fn contains(self: Self, p: V2) bool {
    return ((p.x >= self.x) and (p.x <= self.x + self.width) and
        (p.y >= self.y) and (p.y <= self.y + self.height));
}

pub fn left(self: Self) f32 {
    return self.x;
}
pub fn right(self: Self) f32 {
    return self.x + self.width;
}
pub fn top(self: Self) f32 {
    return self.y;
}
pub fn bottom(self: Self) f32 {
    return self.y + self.height;
}

pub fn topLeft(self: Self) ScreenPoint {
    return .{ .x = self.x, .y = self.y };
}
pub fn topRight(self: Self) ScreenPoint {
    return .{ .x = self.x + self.width, .y = self.y };
}
pub fn bottomLeft(self: Self) ScreenPoint {
    return .{ .x = self.x, .y = self.y + self.height };
}
pub fn bottomRight(self: Self) ScreenPoint {
    return .{ .x = self.x + self.width, .y = self.y + self.height };
}
pub fn center(self: Self) ScreenPoint {
    return .{ .x = self.x + self.width / 2, .y = self.y + self.height / 2 };
}

pub fn inset(self: Self, distance: f32) Self {
    return .{
        .x = self.x + distance,
        .y = self.y + distance,
        .width = self.width - distance * 2,
        .height = self.height - distance * 2,
    };
}
pub fn insetBy(self: Self, l: f32, t: f32, r: f32, b: f32) Self {
    return .{
        .x = self.x + l,
        .y = self.y + t,
        .width = self.width - l - r,
        .height = self.height - t - b,
    };
}
