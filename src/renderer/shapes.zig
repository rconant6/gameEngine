const std = @import("std");
const core = @import("core");
const Point = core.GamePoint;
const col = @import("color.zig");
const Color = col.Color;

pub const Transform = struct {
    offset: ?Point = null,
    rotation: ?f32 = null,
    scale: ?f32 = null,
};

pub const ShapeType = enum {
    Circle,
    Ellipse,
    Line,
    Rectangle,
    Triangle,
    Polygon,
};

pub const ShapeData = union(ShapeType) {
    Circle: Circle,
    Ellipse: Ellipse,
    Line: Line,
    Rectangle: Rectangle,
    Triangle: Triangle,
    Polygon: Polygon,
};
pub const Line = struct {
    start: Point,
    end: Point,
    color: ?Color = null,
};

pub const Triangle = struct {
    vertices: [3]Point,
    outline_color: ?Color = null,
    fill_color: ?Color = null,

    pub fn init(points: []Point) Triangle {
        std.mem.sort(Point, points, {}, sortPointByYThenX);
        return .{
            .vertices = points,
        };
    }
};

pub const Rectangle = struct {
    center: Point,
    half_width: f32,
    half_height: f32,
    outline_color: ?Color = null,
    fill_color: ?Color = null,

    pub fn initSquare(center: Point, size: f32) Rectangle {
        return .{
            .center = center,
            .half_width = size * 0.5,
            .half_height = size * 0.5,
        };
    }

    pub fn initFromCenter(center: Point, width: f32, height: f32) Rectangle {
        return .{
            .center = center,
            .half_width = width * 0.5,
            .half_height = height * 0.5,
        };
    }

    pub fn initFromTopLeft(top_left: Point, width: f32, height: f32) Rectangle {
        return .{
            .center = .{
                .x = top_left.x + width * 0.5,
                .y = top_left.y + height * 0.5,
            },
            .half_width = width,
            .half_height = height,
        };
    }

    pub fn getWidth(self: Rectangle) f32 {
        return self.half_width * 2;
    }

    pub fn getHeight(self: Rectangle) f32 {
        return self.half_height * 2;
    }

    pub fn getCorners(self: *const Rectangle) [4]Point {
        const top_left: Point = .{
            .x = self.center.x - self.half_width,
            .y = self.center.y + self.half_height,
        };
        const top_right: Point = .{
            .x = self.center.x + self.half_width,
            .y = self.center.y + self.half_height,
        };
        const bottom_right: Point = .{
            .x = self.center.x + self.half_width,
            .y = self.center.y - self.half_height,
        };
        const bottom_left: Point = .{
            .x = self.center.x - self.half_width,
            .y = self.center.y - self.half_height,
        };
        return .{ top_left, top_right, bottom_right, bottom_left };
    }
};

pub const Polygon = struct {
    vertices: []const Point,
    center: Point,
    outline_color: ?Color = null,
    fill_color: ?Color = null,

    pub fn init(alloc: std.mem.Allocator, points: []const Point) !Polygon {
        const center = calculateCentroid(points);
        const new_points = try alloc.dupe(Point, points);
        const sort_context = PolygonSortContext{ .centroid = center };
        std.mem.sort(Point, new_points, sort_context, sortPointsClockwise);

        return .{
            .center = center,
            .vertices = new_points,
            .outline_color = null,
            .fill_color = null,
        };
    }
    pub fn deinit(self: *Polygon, alloc: std.mem.Allocator) void {
        alloc.free(self.vertices);
    }
};

pub const Circle = struct {
    origin: Point,
    radius: f32,
    outline_color: ?Color = null,
    fill_color: ?Color = null,
};

pub const Ellipse = struct {
    origin: Point,
    semi_minor: f32,
    semi_major: f32,
    outline_color: ?Color = null,
    fill_color: ?Color = null,
};

fn sortPointByX(context: void, a: Point, b: Point) bool {
    _ = context;
    return a.x > b.x;
}

fn sortPointByY(context: void, a: Point, b: Point) bool {
    _ = context;
    return a.y > b.y;
}

fn sortPointByYThenX(context: void, a: Point, b: Point) bool {
    _ = context;
    if (a.y == b.y) {
        return a.x < b.x;
    }
    return a.y > b.y;
}

fn calculateCentroid(points: []const Point) Point {
    if (points.len == 0) return Point{ .x = 0, .y = 0 };

    var sum_x: f32 = 0;
    var sum_y: f32 = 0;

    for (points) |p| {
        sum_x += p.x;
        sum_y += p.y;
    }

    const flen: f32 = @floatFromInt(points.len);

    return Point{
        .x = sum_x / flen,
        .y = sum_y / flen,
    };
}

const PolygonSortContext = struct {
    centroid: Point,
};

fn sortPointsClockwise(context: PolygonSortContext, a: Point, b: Point) bool {
    const center = context.centroid;

    const angle_a = std.math.atan2(a.y - center.y, a.x - center.x);
    const angle_b = std.math.atan2(b.y - center.y, b.x - center.x);

    return angle_a > angle_b;
}
