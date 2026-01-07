const core = @import("core");
const V2 = core.V2;

pub const CircleCollider = struct {
    origin: V2 = .{ .x = 0, .y = 0 },
    radius: f32,
};
pub const RectangleCollider = struct {
    center: V2 = .{ .x = 0, .y = 0 },
    half_w: f32,
    half_h: f32,
};
