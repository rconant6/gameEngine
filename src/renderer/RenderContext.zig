const Self = @This();
const std = @import("std");
const core = @import("core");
const WorldPoint = core.WorldPoint;
const WorldBounds = core.WorldBounds;

width: u32,
height: u32,
camera_loc: WorldPoint,
ortho_size: f32,

scale_factor: f32 = 1.0,
frame_number: u64 = 0,

time: f64 = 0,
delta_time: f64 = 0,

pub fn aspectRatio(self: *const Self) f32 {
    const fw: f32 = @floatFromInt(self.width);
    const fh: f32 = @floatFromInt(self.height);
    std.debug.assert(fh != 0);
    return fw / fh;
}
