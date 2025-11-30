const Self = @This();

const std = @import("std");

width: u32,
height: u32,

scale_factor: f32 = 1.0,

frame_number: u64 = 0,

time: f64 = 0,

delta_time: f64 = 0,

pub fn aspectRatio(self: *const Self) f32 {
    _ = self;
}
