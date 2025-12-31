const std = @import("std");
const Allocator = std.mem.Allocator;
const core = @import("core");
const Point = core.GamePoint;
const cs = @import("core_shapes.zig");

pub const Transform = struct {
    offset: ?Point = null,
    rotation: ?f32 = null,
    scale: ?f32 = null,
};

pub const ShapeType = enum {
    circle,
    ellipse,
    line,
    rectangle,
    triangle,
    polygon,
};

pub const Shape = union(ShapeType) {
    circle: cs.Circle,
    ellipse: cs.Ellipse,
    line: cs.Line,
    rectangle: cs.Rectangle,
    triangle: cs.Triangle,
    polygon: cs.Polygon,

    pub fn deinit(self: *Shape) void {
        switch (self.*) {
            .polygon => |*p| p.deinit(),
            else => {},
        }
    }
};
