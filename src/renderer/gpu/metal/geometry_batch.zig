const std = @import("std");
const types = @import("metal_types.zig");
const Vertex = types.Vertex;
const MTLPrimitiveType = types.MTLPrimitiveType;
const rend = @import("../../renderer.zig");
const Color = rend.Color;
const Transform = rend.Transform;
const math = @import("math");
const Circle = rend.Shapes.Circle;
const Rectangle = rend.Shapes.Rectangle;
const Triangle = rend.Shapes.Triangle;
const Line = rend.Shapes.Line;
const Ellipse = rend.Shapes.Ellipse;
const Polygon = rend.Shapes.Polygon;
const WorldPoint = math.WorldPoint;
const ShapeData = rend.ShapeData;
const RenderContext = @import("../../RenderContext.zig");
const utils = @import("../../geometry_utils.zig");

pub const DrawCall = struct {
    primitive_type: MTLPrimitiveType,
    vertex_start: u32,
    vertex_count: u32,
};

pub const GeometryBatch = struct {
    vertices: std.ArrayList(Vertex),
    draw_calls: std.ArrayList(DrawCall),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) GeometryBatch {
        return .{
            .vertices = .empty,
            .draw_calls = .empty,
            .allocator = allocator,
        };
    }
    pub fn deinit(self: *GeometryBatch) void {
        self.vertices.deinit(self.allocator);
        self.draw_calls.deinit(self.allocator);
    }
    pub fn clear(self: *GeometryBatch) void {
        self.vertices.clearRetainingCapacity();
        self.draw_calls.clearRetainingCapacity();
    }

    pub fn addShape(
        self: *GeometryBatch,
        shape: ShapeData,
        transform: ?Transform,
        fill_color: ?Color,
        stroke_color: ?Color,
        stroke_width: f32,
        ctx: RenderContext,
    ) !void {
        try addShapeDispatch(
            self,
            shape,
            transform,
            fill_color,
            stroke_color,
            stroke_width,
            ctx,
        );
    }

    fn stripModulePrefix(comptime full_name: []const u8) []const u8 {
        comptime {
            if (std.mem.lastIndexOf(u8, full_name, ".")) |idx| {
                return full_name[idx + 1 ..];
            }
            return full_name;
        }
    }

    fn addShapeDispatch(
        self: *GeometryBatch,
        shape: ShapeData,
        transform: ?Transform,
        fill_color: ?Color,
        stroke_color: ?Color,
        stroke_width: f32,
        ctx: RenderContext,
    ) !void {
        switch (shape) {
            inline else => |s, tag| {
                const name = "add" ++ @tagName(tag);
                if (@hasDecl(@This(), name)) {
                    return @call(.auto, @field(@This(), name), .{
                        self,
                        s,
                        transform,
                        fill_color,
                        stroke_color,
                        stroke_width,
                        ctx,
                    });
                }
            },
        }
    }
    inline fn makeVertex(
        point: WorldPoint,
        xform: ?Transform,
        ctx: RenderContext,
        color: [4]f32,
    ) Vertex {
        const transformed = if (xform) |t| utils.transformPoint(point, t) else point;
        const clip_pos = utils.worldToClipSpace(transformed, ctx);
        return .{ .position = clip_pos, .color = color };
    }
    fn addLine(
        self: *GeometryBatch,
        line: Line,
        transform: ?Transform,
        fill_color: ?Color,
        stroke_color: ?Color,
        stroke_width: f32,
        ctx: RenderContext,
    ) !void {
        _ = fill_color;
        _ = stroke_width;
        if (stroke_color == null) return;

        const batch_offset: u32 = @intCast(self.vertices.items.len);
        const color = utils.colorToFloat(stroke_color.?);

        const vertices = [_]Vertex{
            makeVertex(line.start, transform, ctx, color),
            makeVertex(line.end, transform, ctx, color),
        };
        try self.vertices.appendSlice(self.allocator, &vertices);

        try self.draw_calls.append(
            self.allocator,
            .{
                .primitive_type = .line,
                .vertex_start = batch_offset,
                .vertex_count = 2,
            },
        );
    }
    fn addTriangle(
        self: *GeometryBatch,
        tri: Triangle,
        transform: ?Transform,
        fill_color: ?Color,
        stroke_color: ?Color,
        stroke_width: f32,
        ctx: RenderContext,
    ) !void {
        _ = stroke_width;
        const has_fill = fill_color != null;
        const has_outline = stroke_color != null;
        if (!has_fill and !has_outline) return;

        const vertex_count: u32 = blk: {
            var count: u32 = 0;
            if (has_fill) count += 3;
            if (has_outline) count += 6;
            break :blk count;
        };
        const call_count: u32 = blk: {
            var count: u32 = 0;
            if (has_fill) count += 1;
            if (has_outline) count += 3;
            break :blk count;
        };

        try self.vertices.ensureTotalCapacity(self.allocator, self.vertices.items.len + vertex_count);
        try self.draw_calls.ensureTotalCapacity(self.allocator, self.draw_calls.items.len + call_count);

        const fc = if (has_fill) utils.colorToFloat(fill_color.?) else undefined;
        const sc = if (has_outline) utils.colorToFloat(stroke_color.?) else undefined;

        var batch_offset: u32 = @intCast(self.vertices.items.len);
        if (has_fill) {
            const vertices = [_]Vertex{
                makeVertex(tri.v0, transform, ctx, fc),
                makeVertex(tri.v1, transform, ctx, fc),
                makeVertex(tri.v2, transform, ctx, fc),
            };
            try self.vertices.appendSlice(self.allocator, &vertices);
            try self.draw_calls.append(self.allocator, .{
                .primitive_type = .triangle,
                .vertex_start = batch_offset,
                .vertex_count = 3,
            });
            batch_offset += 3;
        }

        if (has_outline) {
            self.vertices.appendSliceAssumeCapacity(&.{
                makeVertex(tri.v0, transform, ctx, sc),
                makeVertex(tri.v1, transform, ctx, sc),
                makeVertex(tri.v1, transform, ctx, sc),
                makeVertex(tri.v2, transform, ctx, sc),
                makeVertex(tri.v2, transform, ctx, sc),
                makeVertex(tri.v0, transform, ctx, sc),
            });
            self.draw_calls.appendSliceAssumeCapacity(&.{
                .{ .primitive_type = .line, .vertex_start = batch_offset, .vertex_count = 2 },
                .{ .primitive_type = .line, .vertex_start = batch_offset + 2, .vertex_count = 2 },
                .{ .primitive_type = .line, .vertex_start = batch_offset + 4, .vertex_count = 2 },
            });
        }
    }
    fn addRectangle(
        self: *GeometryBatch,
        rect: Rectangle,
        transform: ?Transform,
        fill_color: ?Color,
        stroke_color: ?Color,
        stroke_width: f32,
        ctx: RenderContext,
    ) !void {
        _ = stroke_width;
        const has_fill = fill_color != null;
        const has_outline = stroke_color != null;
        if (!has_fill and !has_outline) return;

        const vertex_count: u32 = blk: {
            var count: u32 = 0;
            if (has_fill) count += 6;
            if (has_outline) count += 8;
            break :blk count;
        };
        const call_count: u32 = blk: {
            var count: u32 = 0;
            if (has_fill) count += 2;
            if (has_outline) count += 4;
            break :blk count;
        };

        try self.vertices.ensureTotalCapacity(self.allocator, self.vertices.items.len + vertex_count);
        try self.draw_calls.ensureTotalCapacity(self.allocator, self.draw_calls.items.len + call_count);

        const fc = if (has_fill) utils.colorToFloat(fill_color.?) else undefined;
        const sc = if (has_outline) utils.colorToFloat(stroke_color.?) else undefined;

        const corners = rect.getCorners();
        var batch_offset: u32 = @intCast(self.vertices.items.len);
        if (has_fill) {
            self.vertices.appendSliceAssumeCapacity(&.{
                // Tri 1
                makeVertex(corners[0], transform, ctx, fc),
                makeVertex(corners[1], transform, ctx, fc),
                makeVertex(corners[2], transform, ctx, fc),
                // Tri 2
                makeVertex(corners[0], transform, ctx, fc),
                makeVertex(corners[2], transform, ctx, fc),
                makeVertex(corners[3], transform, ctx, fc),
            });
            self.draw_calls.appendSliceAssumeCapacity(&.{
                .{ .primitive_type = .triangle, .vertex_start = batch_offset, .vertex_count = 3 },
                .{ .primitive_type = .triangle, .vertex_start = batch_offset + 3, .vertex_count = 3 },
            });
            batch_offset += 6;
        }
        if (has_outline) {
            self.vertices.appendSliceAssumeCapacity(&.{
                makeVertex(corners[0], transform, ctx, sc),
                makeVertex(corners[1], transform, ctx, sc),
                makeVertex(corners[1], transform, ctx, sc),
                makeVertex(corners[2], transform, ctx, sc),
                makeVertex(corners[2], transform, ctx, sc),
                makeVertex(corners[3], transform, ctx, sc),
                makeVertex(corners[3], transform, ctx, sc),
                makeVertex(corners[0], transform, ctx, sc),
            });
            self.draw_calls.appendSliceAssumeCapacity(&.{
                .{ .primitive_type = .line, .vertex_start = batch_offset, .vertex_count = 2 },
                .{ .primitive_type = .line, .vertex_start = batch_offset + 2, .vertex_count = 2 },
                .{ .primitive_type = .line, .vertex_start = batch_offset + 4, .vertex_count = 2 },
                .{ .primitive_type = .line, .vertex_start = batch_offset + 6, .vertex_count = 2 },
            });
        }
    }
    fn addPolygon(
        self: *GeometryBatch,
        poly: Polygon,
        transform: ?Transform,
        fill_color: ?Color,
        stroke_color: ?Color,
        stroke_width: f32,
        ctx: RenderContext,
    ) !void {
        _ = stroke_width;
        const has_fill = fill_color != null;
        const has_outline = stroke_color != null;
        if (!has_fill and !has_outline) return;

        const cache = poly.triangle_cache orelse return error.InvalidPolygon;

        const vertex_count = poly.vertex_count;
        const call_count = (if (has_fill) poly.fill_call_count else 0) +
            (if (has_outline) poly.outline_call_count else 0);

        try self.vertices.ensureTotalCapacity(self.allocator, self.vertices.items.len + vertex_count);
        try self.draw_calls.ensureTotalCapacity(self.allocator, self.draw_calls.items.len + call_count);

        const fc = if (has_fill) utils.colorToFloat(fill_color.?) else undefined;
        const sc = if (has_outline) utils.colorToFloat(stroke_color.?) else undefined;

        const fill_start = self.vertices.items.len;
        if (has_fill) {
            for (cache) |tris| {
                self.vertices.appendSliceAssumeCapacity(&.{
                    makeVertex(tris[0], transform, ctx, fc),
                    makeVertex(tris[1], transform, ctx, fc),
                    makeVertex(tris[2], transform, ctx, fc),
                });
            }

            self.draw_calls.appendAssumeCapacity(.{
                .primitive_type = .triangle,
                .vertex_start = @intCast(fill_start),
                .vertex_count = @intCast(cache.len * 3),
            });
        }

        if (has_outline) {
            for (poly.points, 0..) |point, i| {
                const edge_start = self.vertices.items.len;
                const v1 = point;
                const v2 = poly.points[(i + 1) % poly.points.len];
                self.vertices.appendSliceAssumeCapacity(&.{
                    makeVertex(v1, transform, ctx, sc),
                    makeVertex(v2, transform, ctx, sc),
                });
                self.draw_calls.appendAssumeCapacity(.{
                    .primitive_type = .line,
                    .vertex_start = @intCast(edge_start),
                    .vertex_count = 2,
                });
            }
        }
    }
    fn addCircle(
        self: *GeometryBatch,
        circle: Circle,
        transform: ?Transform,
        fill_color: ?Color,
        stroke_color: ?Color,
        stroke_width: f32,
        ctx: RenderContext,
    ) !void {
        _ = stroke_width;
        const has_fill = fill_color != null;
        const has_outline = stroke_color != null;
        if (!has_fill and !has_outline) return;

        const segments = 32; // TODO: adapt to screen space (16, 32, 64, 128)
        const angle_step = std.math.tau / @as(f32, @floatFromInt(segments));

        const vertex_count: u32 = blk: {
            var count: u32 = 0;
            if (has_fill) count += segments * 3;
            if (has_outline) count += segments * 2;
            break :blk count;
        };
        const call_count: u32 = blk: {
            var count: u32 = 0;
            if (has_fill) count += segments * 2;
            if (has_outline) count += segments;
            break :blk count;
        };

        try self.vertices.ensureTotalCapacity(self.allocator, self.vertices.items.len + vertex_count);
        try self.draw_calls.ensureTotalCapacity(self.allocator, self.draw_calls.items.len + call_count);

        const fc = if (has_fill) utils.colorToFloat(fill_color.?) else undefined;
        const sc = if (has_outline) utils.colorToFloat(stroke_color.?) else undefined;

        for (0..segments) |i| {
            const i_f: f32 = @floatFromInt(i);
            const angle1 = i_f * angle_step;
            const angle2 = (i_f + 1.0) * angle_step;

            const p1 = WorldPoint{
                .x = circle.origin.x + circle.radius * @cos(angle1),
                .y = circle.origin.y + circle.radius * @sin(angle1),
            };
            const p2 = WorldPoint{
                .x = circle.origin.x + circle.radius * @cos(angle2),
                .y = circle.origin.y + circle.radius * @sin(angle2),
            };

            if (has_fill) {
                const current_offset: u32 = @intCast(self.vertices.items.len);
                self.vertices.appendSliceAssumeCapacity(&.{
                    makeVertex(circle.origin, transform, ctx, fc),
                    makeVertex(p1, transform, ctx, fc),
                    makeVertex(p2, transform, ctx, fc),
                });
                self.draw_calls.appendAssumeCapacity(.{
                    .primitive_type = .triangle,
                    .vertex_start = current_offset,
                    .vertex_count = 3,
                });
            }

            if (has_outline) {
                const current_offset: u32 = @intCast(self.vertices.items.len);
                self.vertices.appendSliceAssumeCapacity(&.{
                    makeVertex(p1, transform, ctx, sc),
                    makeVertex(p2, transform, ctx, sc),
                });
                self.draw_calls.appendAssumeCapacity(.{
                    .primitive_type = .line,
                    .vertex_start = current_offset,
                    .vertex_count = 2,
                });
            }
        }
    }
    fn addEllipse(
        self: *GeometryBatch,
        shape: Ellipse,
        transform: ?Transform,
        fill_color: ?Color,
        stroke_color: ?Color,
        stroke_width: f32,
        ctx: RenderContext,
    ) !void {
        _ = self;
        _ = shape;
        _ = transform;
        _ = fill_color;
        _ = stroke_color;
        _ = stroke_width;
        _ = ctx;
    }
};
