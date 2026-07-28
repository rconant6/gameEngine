const std = @import("std");
const Allocator = std.mem.Allocator;
const math = @import("math");
const V2 = math.V2;
const hf = math.utils;
const tris = @import("triangulation");
const log = @import("debug").log;

pub const Circle = struct {
    origin: V2,
    radius: f32,
};

pub const Rectangle = struct {
    center: V2,
    half_height: f32,
    half_width: f32,

    pub fn init(
        x: f32,
        y: f32,
        w: f32,
        h: f32,
    ) !@This() {
        return .{
            .center = .{ .x = x - w / 2, .y = y - h / 2 },
            .half_width = w / 2,
            .half_height = h / 2,
        };
    }

    pub fn initSquare(center: V2, size: f32) @This() {
        return .{
            .center = center,
            .half_width = size * 0.5,
            .half_height = size * 0.5,
        };
    }

    pub fn initFromCenter(
        center: V2,
        width: f32,
        height: f32,
    ) @This() {
        return .{
            .center = center,
            .half_width = width * 0.5,
            .half_height = height * 0.5,
        };
    }

    pub fn initFromTopLeft(
        top_left: V2,
        width: f32,
        height: f32,
    ) @This() {
        return .{
            .center = .{
                .x = top_left.x + width * 0.5,
                .y = top_left.y + height * 0.5,
            },
            .half_width = width / 2,
            .half_height = height / 2,
        };
    }

    pub fn getWidth(self: @This()) f32 {
        return self.half_width * 2;
    }

    pub fn getHeight(self: @This()) f32 {
        return self.half_height * 2;
    }

    pub fn getCorners(self: *const @This()) [4]V2 {
        const hw = self.half_width;
        const hh = self.half_height;

        const top_left: V2 = .{
            .x = self.center.x - hw,
            .y = self.center.y + hh,
        };
        const top_right: V2 = .{
            .x = self.center.x + hw,
            .y = self.center.y + hh,
        };
        const bottom_right: V2 = .{
            .x = self.center.x + hw,
            .y = self.center.y - hh,
        };
        const bottom_left: V2 = .{
            .x = self.center.x - hw,
            .y = self.center.y - hh,
        };
        return .{ bottom_left, bottom_right, top_right, top_left };
    }
};

pub const RoundedRect = struct {
    center: V2,
    half_width: f32,
    half_height: f32,
    radius: f32,

    pub fn init(
        x: f32,
        y: f32,
        w: f32,
        h: f32,
        radius: f32,
    ) !@This() {
        return .{
            .center = .{ .x = x - w / 2, .y = y - h / 2 },
            .half_width = w / 2,
            .half_height = h / 2,
            .radius = radius,
        };
    }

    pub fn initSquare(center: V2, size: f32, radius: f32) @This() {
        return .{
            .center = center,
            .half_width = size * 0.5,
            .half_height = size * 0.5,
            .radius = radius,
        };
    }

    pub fn initFromCenter(
        center: V2,
        width: f32,
        height: f32,
        radius: f32,
    ) @This() {
        return .{
            .center = center,
            .half_width = width * 0.5,
            .half_height = height * 0.5,
            .radius = radius,
        };
    }

    pub fn initFromTopLeft(
        top_left: V2,
        width: f32,
        height: f32,
        radius: f32,
    ) @This() {
        return .{
            .center = .{
                .x = top_left.x + width * 0.5,
                .y = top_left.y + height * 0.5,
            },
            .half_width = width / 2,
            .half_height = height / 2,
            .radius = radius,
        };
    }

    pub fn getWidth(self: @This()) f32 {
        return self.half_width * 2;
    }

    pub fn getHeight(self: @This()) f32 {
        return self.half_height * 2;
    }

    pub fn getCorners(self: *const @This()) [4]V2 {
        const hw = self.half_width;
        const hh = self.half_height;
        const top_left: V2 = .{
            .x = self.center.x - hw,
            .y = self.center.y + hh,
        };
        const top_right: V2 = .{
            .x = self.center.x + hw,
            .y = self.center.y + hh,
        };
        const bottom_right: V2 = .{
            .x = self.center.x + hw,
            .y = self.center.y - hh,
        };
        const bottom_left: V2 = .{
            .x = self.center.x - hw,
            .y = self.center.y - hh,
        };
        return .{ bottom_left, bottom_right, top_right, top_left };
    }
};

pub const Triangle = struct {
    v0: V2,
    v1: V2,
    v2: V2,

    pub fn init(
        points: []const V2,
    ) @This() {
        log.err(
            .renderer,
            "Triangle creation without 3 points {d}",
            .{points.len},
        );
        var verts = [3]V2{ points[0], points[1], points[2] };
        std.mem.sort(V2, &verts, {}, hf.sortPointByYThenX);
        return .{
            .v0 = verts[0],
            .v1 = verts[1],
            .v2 = verts[2],
        };
    }
};

pub const Arc = struct {
    origin: V2,
    radius: f32,
    thickness: f32, // 0 wedge, >0 ring segment
    start_angle: f32, // radians
    end_angle: f32,
};

pub const Line = struct {
    start: V2,
    end: V2,
};

pub const PolyLine = struct {
    gpa: Allocator,
    points: []const V2,

    pub fn init(
        gpa: Allocator,
        points: []const V2,
    ) !@This() {
        const owned_points = try gpa.dupe(V2, points);
        errdefer gpa.free(owned_points);

        return .{
            .gpa = gpa,
            .points = owned_points,
        };
    }

    pub fn deinit(self: *@This()) void {
        self.gpa.free(self.points);
    }
};

pub const Polygon = struct {
    gpa: Allocator,
    points: []const V2,
    center: V2 = .{ .x = 0, .y = 0 },
    fill_call_count: usize = 0,
    outline_call_count: usize = 0,
    triangle_cache: ?[][3]V2 = null,
    vertex_count: usize = 0,

    pub fn init(
        gpa: Allocator,
        points: []const V2,
    ) !@This() {
        const owned_points = try gpa.dupe(V2, points);
        errdefer gpa.free(owned_points);

        const area = tris.signedArea(owned_points);
        if (area < 0) {
            std.mem.reverse(V2, owned_points);
        }

        const center = hf.calculateCentroid(owned_points);

        var poly: @This() = .{
            .gpa = gpa,
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

    pub fn deinit(self: *@This()) void {
        if (self.triangle_cache) |triangles| self.gpa.free(triangles);
        self.gpa.free(self.points);
    }

    pub fn getTriangles(self: *@This()) ![][3]V2 {
        if (self.triangle_cache) |triangles| return triangles;

        const triangles = try tris.triangulate(self.gpa, self.points);

        self.triangle_cache = triangles;
        return triangles;
    }
};

pub const Ellipse = struct {
    origin: V2,
    semi_minor: f32,
    semi_major: f32,
};

pub const Capsule = struct {
    center: V2,
    half_width: f32,
    half_height: f32,

    pub fn init(center: V2, w: f32, h: f32) @This() {
        return .{
            .center = center,
            .half_width = w * 0.5,
            .half_height = h * 0.5,
        };
    }

    pub fn getWidth(self: @This()) f32 {
        return self.half_width * 2;
    }

    pub fn getHeight(self: @This()) f32 {
        return self.half_height * 2;
    }
};

pub const NGon = struct {
    origin: V2,
    radius: f32,
    sides: u32,
};

pub const Star = struct {
    origin: V2,
    outer_radius: f32,
    inner_radius: f32,
    points: u32,
};
