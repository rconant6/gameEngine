const std = @import("std");
const Allocator = std.mem.Allocator;
const hf = @import("math").utils;
const tris = @import("triangulation.zig");
// NOTE: These need to stay in this order in the file to keep collision working? (maybe)
// Circle => 0
// Rectangle => 1

pub fn Circle(comptime PointType: type) type {
    return struct {
        origin: PointType,
        radius: f32,

        pub fn init(
            alloc: Allocator,
            origin: PointType,
            r: f32,
        ) !@This() {
            _ = alloc;
            return .{
                .origin = origin,
                .radius = r,
            };
        }
    };
}

pub fn Rectangle(comptime PointType: type) type {
    return struct {
        center: PointType,
        half_height: f32,
        half_width: f32,

        pub fn init(
            alloc: Allocator,
            x: f32,
            y: f32,
            w: f32,
            h: f32,
        ) !@This() {
            _ = alloc;
            return .{
                .center = .{ .x = x - w / 2, .y = y - h / 2 },
                .half_width = w / 2,
                .half_height = h / 2,
            };
        }

        pub fn initSquare(center: PointType, size: f32) @This() {
            return .{
                .center = center,
                .half_width = size * 0.5,
                .half_height = size * 0.5,
            };
        }

        pub fn initFromCenter(center: PointType, width: f32, height: f32) @This() {
            return .{
                .center = center,
                .half_width = width * 0.5,
                .half_height = height * 0.5,
            };
        }

        pub fn initFromTopLeft(top_left: PointType, width: f32, height: f32) @This() {
            return .{
                .center = .{
                    .x = top_left.x + width * 0.5,
                    .y = top_left.y + height * 0.5,
                },
                .half_width = width,
                .half_height = height,
            };
        }

        pub fn getWidth(self: @This()) f32 {
            return self.half_width * 2;
        }

        pub fn getHeight(self: @This()) f32 {
            return self.half_height * 2;
        }

        pub fn getCorners(self: *const @This()) [4]PointType {
            const XType = @TypeOf(self.center.x);
            const hw = if (XType == i32) @as(i32, @intFromFloat(self.half_width)) else self.half_width;
            const hh = if (XType == i32) @as(i32, @intFromFloat(self.half_height)) else self.half_height;

            const top_left: PointType = .{
                .x = self.center.x - hw,
                .y = self.center.y + hh,
            };
            const top_right: PointType = .{
                .x = self.center.x + hw,
                .y = self.center.y + hh,
            };
            const bottom_right: PointType = .{
                .x = self.center.x + hw,
                .y = self.center.y - hh,
            };
            const bottom_left: PointType = .{
                .x = self.center.x - hw,
                .y = self.center.y - hh,
            };
            return .{ top_left, top_right, bottom_right, bottom_left };
        }
    };
}

pub fn Triangle(comptime PointType: type) type {
    return struct {
        v0: PointType,
        v1: PointType,
        v2: PointType,

        pub fn init(
            alloc: Allocator,
            points: []const PointType,
        ) !@This() {
            _ = alloc;
            std.debug.assert(points.len == 3);
            var verts = [3]PointType{ points[0], points[1], points[2] };
            std.mem.sort(PointType, &verts, {}, hf.sortPointByYThenX);
            return .{
                .v0 = verts[0],
                .v1 = verts[1],
                .v2 = verts[2],
            };
        }
    };
}

pub fn Line(comptime PointType: type) type {
    return struct {
        start: PointType,
        end: PointType,

        pub fn init(
            alloc: Allocator,
            start: PointType,
            end: PointType,
        ) !@This() {
            _ = alloc;
            return .{
                .start = start,
                .end = end,
            };
        }
    };
}

pub fn Polygon(comptime PointType: type) type {
    return struct {
        allocator: Allocator,
        points: []const PointType,
        center: PointType = .{ .x = 0, .y = 0 },
        fill_call_count: usize = 0,
        outline_call_count: usize = 0,
        triangle_cache: ?[][3]PointType = null,
        vertex_count: usize = 0,

        pub fn init(
            alloc: Allocator,
            points: []const PointType,
        ) !@This() {
            const owned_points = try alloc.dupe(PointType, points);
            errdefer alloc.free(owned_points);

            const area = tris.signedArea(owned_points);
            if (area < 0) {
                std.mem.reverse(PointType, owned_points);
            }

            const center = hf.calculateCentroid(owned_points);

            var poly: @This() = .{
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

        pub fn deinit(self: *@This()) void {
            if (self.triangle_cache) |triangles| self.allocator.free(triangles);
            self.allocator.free(self.points);
        }

        pub fn getTriangles(self: *@This()) ![][3]PointType {
            if (self.triangle_cache) |triangles| return triangles;

            const triangles = try tris.triangulate(self.allocator, self.points);

            self.triangle_cache = triangles;
            return triangles;
        }
    };
}

// TODO: NOT IMPLEMENTED
pub fn Ellipse(comptime PointType: type) type {
    return struct {
        origin: PointType,
        semi_minor: f32,
        semi_major: f32,
    };
}
