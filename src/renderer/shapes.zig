const std = @import("std");
const Allocator = std.mem.Allocator;
const core = @import("core");
const Point = core.GamePoint;
const col = @import("color.zig");
const Color = col.Color;
const tris = @import("triangulation.zig");

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

pub const Shape = union(ShapeType) {
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

    pub fn init(
        alloc: Allocator,
        start: Point,
        end: Point,
        c: ?Color,
    ) !Line {
        _ = alloc;
        return .{
            .start = start,
            .end = end,
            .color = c,
        };
    }
};

pub const Triangle = struct {
    allocator: Allocator,
    vertices: []Point,
    outline_color: ?Color = null,
    fill_color: ?Color = null,

    pub fn init(alloc: Allocator, points: []const Point, fc: ?Color, oc: ?Color) !Triangle {
        const owned_points: []Point = try alloc.dupe(Point, points);
        std.debug.assert(owned_points.len == 3);
        std.mem.sort(Point, owned_points, {}, sortPointByYThenX);
        return .{
            .allocator = alloc,
            .vertices = owned_points,
            .outline_color = oc,
            .fill_color = fc,
        };
    }
    pub fn deinit(tri: *Triangle) void {
        try .allocator.free(tri.vertices);
    }
};

pub const Rectangle = struct {
    center: Point,
    fill_color: ?Color = null,
    half_height: f32,
    half_width: f32,
    outline_color: ?Color = null,

    pub fn init(
        alloc: Allocator,
        x: f32,
        y: f32,
        w: f32,
        h: f32,
        fc: ?Color,
        oc: ?Color,
    ) !Rectangle {
        _ = alloc;
        return .{
            .center = .{ .x = x - w / 2, .y = y - h / 2 },
            .half_width = w / 2,
            .half_height = h / 2,
            .outline_color = oc,
            .fill_color = fc,
        };
    }

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
    allocator: Allocator,
    center: Point,
    fill_call_count: usize = 0,
    fill_color: ?Color = null,
    outline_call_count: usize = 0,
    outline_color: ?Color = null,
    points: []const Point,
    triangle_cache: ?[][3]Point = null,
    vertex_count: usize = 0,

    pub fn init(
        alloc: Allocator,
        points: []const Point,
        fc: ?Color,
        oc: ?Color,
    ) !Polygon {
        const owned_points = try alloc.dupe(Point, points);
        errdefer alloc.free(owned_points);
        const center = calculateCentroid(owned_points);

        var poly: Polygon = .{
            .allocator = alloc,
            .points = owned_points,
            .center = center,
            .outline_color = oc,
            .fill_color = fc,
            .triangle_cache = null,
        };

        const cache = try poly.getTriangles();
        const fill_vertex_count = cache.len * 3;
        const outline_count = points.len * 2;

        poly.triangle_cache = cache;
        poly.vertex_count = fill_vertex_count + outline_count;
        poly.fill_call_count = 1;
        poly.outline_call_count = outline_count;

        return poly;
    }

    pub fn deinit(self: *Polygon) void {
        if (self.triangle_cache) |triangles| self.allocator.free(triangles);
        self.allocator.free(self.points);
    }

    pub fn getTriangles(self: *Polygon) ![][3]Point {
        if (self.triangle_cache) |triangles| return triangles;

        const triangles = try tris.triangulate(self.allocator, self.points);

        self.triangle_cache = triangles;
        return triangles;
    }
};

pub const Circle = struct {
    fill_color: ?Color = null,
    origin: Point,
    outline_color: ?Color = null,
    radius: f32,

    pub fn init(
        alloc: Allocator,
        origin: Point,
        r: f32,
        fc: ?Color,
        oc: ?Color,
    ) !Circle {
        _ = alloc;
        return .{
            .fill_color = fc,
            .origin = origin,
            .outline_color = oc,
            .radius = r,
        };
    }
};

// TODO: NOT IMPLEMENTED
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
