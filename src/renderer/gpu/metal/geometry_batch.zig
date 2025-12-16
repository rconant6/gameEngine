const std = @import("std");
const types = @import("metal_types.zig");
const Vertex = types.Vertex;
const MTLPrimitiveType = types.MTLPrimitiveType;
const rend = @import("../../renderer.zig");
const Color = rend.Color;
const Shape = rend.Shape;
const Transform = rend.Transform;
const Circle = rend.Circle;
const Rectangle = rend.Rectangle;
const Triangle = rend.Triangle;
const Line = rend.Line;
const Ellipse = rend.Ellipse;
const Polygon = rend.Polygon;
const core = @import("core");
const GamePoint = core.GamePoint;
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
        shape: Shape,
        transform: ?Transform,
        ctx: RenderContext,
    ) !void {
        switch (shape) {
            .Triangle => |tri| try addTriangle(self, tri, transform, ctx),
            .Line => |l| try addLine(self, l, transform, ctx),
            .Rectangle => |rect| try addRectangle(self, rect, transform, ctx),
            .Polygon => |poly| try addPolygon(self, poly, transform, ctx),
            .Circle => |circ| try addCircle(self, circ, transform, ctx),
            .Ellipse => @panic("TODO: Ellipse not supported"),
        }
    }
    inline fn makeVertex(
        point: GamePoint,
        xform: ?Transform,
        ctx: RenderContext,
        color: [4]f32,
    ) Vertex {
        const transformed = if (xform) |t| utils.transformPoint(point, t) else point;
        const clip_pos = utils.gameToClipSpace(transformed, ctx);
        return .{ .position = clip_pos, .color = color };
    }
    fn addLine(
        self: *GeometryBatch,
        line: Line,
        transform: ?Transform,
        ctx: RenderContext,
    ) !void {
        if (line.color == null) return;

        const batch_offset: u32 = @intCast(self.vertices.items.len);
        const color = utils.colorToFloat(line.color.?);

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
        ctx: RenderContext,
    ) !void {
        const has_fill = tri.fill_color != null;
        const has_outline = tri.outline_color != null;
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

        const fill_color = if (has_fill) utils.colorToFloat(tri.fill_color.?) else undefined;
        const outline_color = if (has_outline) utils.colorToFloat(tri.outline_color.?) else undefined;

        const batch_offset: u32 = @intCast(self.vertices.items.len);
        if (has_fill) {
            const vertices = [_]Vertex{
                makeVertex(tri.vertices[0], transform, ctx, fill_color),
                makeVertex(tri.vertices[1], transform, ctx, fill_color),
                makeVertex(tri.vertices[2], transform, ctx, fill_color),
            };
            try self.vertices.appendSlice(self.allocator, &vertices);
            try self.draw_calls.append(self.allocator, .{
                .primitive_type = .triangle,
                .vertex_start = batch_offset,
                .vertex_count = 3,
            });
        }

        if (has_outline) {
            self.vertices.appendSliceAssumeCapacity(&.{
                makeVertex(tri.vertices[0], transform, ctx, outline_color),
                makeVertex(tri.vertices[1], transform, ctx, outline_color),
                makeVertex(tri.vertices[1], transform, ctx, outline_color),
                makeVertex(tri.vertices[2], transform, ctx, outline_color),
                makeVertex(tri.vertices[2], transform, ctx, outline_color),
                makeVertex(tri.vertices[0], transform, ctx, outline_color),
            });
            self.draw_calls.appendSliceAssumeCapacity(&.{
                .{ .primitive_type = .line, .vertex_start = batch_offset + 3, .vertex_count = 2 },
                .{ .primitive_type = .line, .vertex_start = batch_offset + 5, .vertex_count = 2 },
                .{ .primitive_type = .line, .vertex_start = batch_offset + 7, .vertex_count = 2 },
            });
        }
    }
    fn addRectangle(
        self: *GeometryBatch,
        rect: Rectangle,
        transform: ?Transform,
        ctx: RenderContext,
    ) !void {
        const has_fill = rect.fill_color != null;
        const has_outline = rect.outline_color != null;
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

        const fill_color = if (has_fill) utils.colorToFloat(rect.fill_color.?) else undefined;
        const outline_color = if (has_outline) utils.colorToFloat(rect.outline_color.?) else undefined;

        const corners = rect.getCorners();
        var batch_offset: u32 = @intCast(self.vertices.items.len);
        if (has_fill) {
            self.vertices.appendSliceAssumeCapacity(&.{
                // Tri 1
                makeVertex(corners[0], transform, ctx, fill_color),
                makeVertex(corners[1], transform, ctx, fill_color),
                makeVertex(corners[2], transform, ctx, fill_color),
                // Tri 2
                makeVertex(corners[0], transform, ctx, fill_color),
                makeVertex(corners[2], transform, ctx, fill_color),
                makeVertex(corners[3], transform, ctx, fill_color),
            });
            self.draw_calls.appendSliceAssumeCapacity(&.{
                .{ .primitive_type = .triangle, .vertex_start = batch_offset, .vertex_count = 3 },
                .{ .primitive_type = .triangle, .vertex_start = batch_offset + 3, .vertex_count = 3 },
            });
        }
        batch_offset += 6;
        if (has_outline) {
            self.vertices.appendSliceAssumeCapacity(&.{
                makeVertex(corners[0], transform, ctx, outline_color),
                makeVertex(corners[1], transform, ctx, outline_color),
                makeVertex(corners[1], transform, ctx, outline_color),
                makeVertex(corners[2], transform, ctx, outline_color),
                makeVertex(corners[2], transform, ctx, outline_color),
                makeVertex(corners[3], transform, ctx, outline_color),
                makeVertex(corners[3], transform, ctx, outline_color),
                makeVertex(corners[0], transform, ctx, outline_color),
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
        ctx: RenderContext,
    ) !void {
        const has_fill = poly.fill_color != null;
        const has_outline = poly.outline_color != null;
        if (!has_fill and !has_outline) return;

        const vertex_count: u32 = blk: {
            var count: u32 = 0;
            if (has_fill) count += @intCast(self.vertices.items.len * 3);
            if (has_outline) count += @intCast(self.vertices.items.len * 2);
            break :blk count;
        };
        const call_count: u32 = blk: {
            var count: u32 = 0;
            if (has_fill) count += @intCast(self.vertices.items.len);
            if (has_outline) count += @intCast(self.vertices.items.len);
            break :blk count;
        };

        try self.vertices.ensureTotalCapacity(self.allocator, self.vertices.items.len + vertex_count);
        try self.draw_calls.ensureTotalCapacity(self.allocator, self.draw_calls.items.len + call_count);

        const fill_color = if (has_fill) utils.colorToFloat(poly.fill_color.?) else undefined;
        const outline_color = if (has_outline) utils.colorToFloat(poly.outline_color.?) else undefined;

        const num_tris = poly.vertices.len;
        for (0..num_tris) |i| {
            const v1 = poly.vertices[i];
            const v2 = poly.vertices[(i + 1) % num_tris];
            if (has_fill) {
                const current_offset: u32 = @intCast(self.vertices.items.len);
                self.vertices.appendSliceAssumeCapacity(&.{
                    makeVertex(poly.center, transform, ctx, fill_color),
                    makeVertex(v1, transform, ctx, fill_color),
                    makeVertex(v2, transform, ctx, fill_color),
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
                    makeVertex(v1, transform, ctx, outline_color),
                    makeVertex(v2, transform, ctx, outline_color),
                });
                self.draw_calls.appendAssumeCapacity(.{
                    .primitive_type = .line,
                    .vertex_start = current_offset,
                    .vertex_count = 2,
                });
            }
        }
    }
    fn addCircle(
        self: *GeometryBatch,
        circle: Circle,
        transform: ?Transform,
        ctx: RenderContext,
    ) !void {
        const has_fill = circle.fill_color != null;
        const has_outline = circle.outline_color != null;
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

        const fill_color = if (has_fill) utils.colorToFloat(circle.fill_color.?) else undefined;
        const outline_color = if (has_outline) utils.colorToFloat(circle.outline_color.?) else undefined;

        for (0..segments) |i| {
            const i_f: f32 = @floatFromInt(i);
            const angle1 = i_f * angle_step;
            const angle2 = (i_f + 1.0) * angle_step;

            const p1 = GamePoint{
                .x = circle.origin.x + circle.radius * @cos(angle1),
                .y = circle.origin.y + circle.radius * @sin(angle1),
            };
            const p2 = GamePoint{
                .x = circle.origin.x + circle.radius * @cos(angle2),
                .y = circle.origin.y + circle.radius * @sin(angle2),
            };

            if (has_fill) {
                const current_offset: u32 = @intCast(self.vertices.items.len);
                self.vertices.appendSliceAssumeCapacity(&.{
                    makeVertex(circle.origin, transform, ctx, fill_color),
                    makeVertex(p1, transform, ctx, fill_color),
                    makeVertex(p2, transform, ctx, fill_color),
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
                    makeVertex(p1, transform, ctx, outline_color),
                    makeVertex(p2, transform, ctx, outline_color),
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
        ctx: *const RenderContext,
    ) !void {
        _ = self;
        _ = shape;
        _ = transform;
        _ = ctx;
    }
};
