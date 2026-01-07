const std = @import("std");
const Allocator = std.mem.Allocator;
const Point = @import("V2.zig").V2;
const hf = @import("helper_funtions.zig");
const tris = @import("triangulation.zig");
// NOTE: These need to be in the right order in the file
// inorder to keep collision working
// Circle => 0
// Rectangle => 2

pub const Circle = struct {
    origin: Point,
    radius: f32,

    pub fn init(
        alloc: Allocator,
        origin: Point,
        r: f32,
    ) !Circle {
        _ = alloc;
        return .{
            .origin = origin,
            .radius = r,
        };
    }
};

pub const Rectangle = struct {
    center: Point,
    half_height: f32,
    half_width: f32,

    pub fn init(
        alloc: Allocator,
        x: f32,
        y: f32,
        w: f32,
        h: f32,
    ) !Rectangle {
        _ = alloc;
        return .{
            .center = .{ .x = x - w / 2, .y = y - h / 2 },
            .half_width = w / 2,
            .half_height = h / 2,
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

pub const Triangle = struct {
    v0: Point,
    v1: Point,
    v2: Point,

    pub fn init(
        alloc: Allocator,
        points: []const Point,
    ) !Triangle {
        _ = alloc;
        std.debug.assert(points.len == 3);
        var verts = [3]Point{ points[0], points[1], points[2] };
        std.mem.sort(Point, &verts, {}, hf.sortPointByYThenX);
        return .{
            .v0 = verts[0],
            .v1 = verts[1],
            .v2 = verts[2],
        };
    }
};

pub const Line = struct {
    start: Point,
    end: Point,

    pub fn init(
        alloc: Allocator,
        start: Point,
        end: Point,
    ) !Line {
        _ = alloc;
        return .{
            .start = start,
            .end = end,
        };
    }
};

pub const Polygon = struct {
    allocator: Allocator,
    points: []const Point,
    center: Point = .{ .x = 0, .y = 0 },
    fill_call_count: usize = 0,
    outline_call_count: usize = 0,
    triangle_cache: ?[][3]Point = null,
    vertex_count: usize = 0,

    pub fn init(
        alloc: Allocator,
        points: []const Point,
    ) !Polygon {
        const owned_points = try alloc.dupe(Point, points);
        errdefer alloc.free(owned_points);

        const area = tris.signedArea(owned_points);
        if (area < 0) {
            std.mem.reverse(Point, owned_points);
        }

        const center = hf.calculateCentroid(owned_points);

        var poly: Polygon = .{
            .allocator = alloc,
            .points = owned_points,
            .center = center,
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

// TODO: NOT IMPLEMENTED
pub const Ellipse = struct {
    origin: Point,
    semi_minor: f32,
    semi_major: f32,
};
