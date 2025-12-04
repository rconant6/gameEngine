const std = @import("std");
const types = @import("metal_types.zig");
const Vertex = types.Vertex;
const MTLPrimitiveType = types.MTLPrimitiveType;
const rend = @import("../../renderer.zig");
const Color = rend.Color;
const ShapeData = rend.ShapeData;
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
        shape: ShapeData,
        transform: ?Transform,
        ctx: RenderContext,
    ) !void {
        switch (shape) {
            .Triangle => |tri| try addTriangle(self, tri, transform, ctx),
            .Line => |l| try addLine(self, l, transform, ctx),
            .Rectangle => |rect| try addRectangle(self, rect, transform, ctx),
            .Polygon => |poly| try addPolygon(self, poly, transform, ctx),
            .Circle => |circ| try addCircle(self, circ, transform, ctx),
            // TODO: need to add the rest
            // Ellipse
            else => unreachable,
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
        if (tri.fill_color == null) return; // TODO: Draw the outline

        const batch_offset: u32 = @intCast(self.vertices.items.len);
        const color = utils.colorToFloat(tri.fill_color.?);

        const vertices = [_]Vertex{
            makeVertex(tri.vertices[0], transform, ctx, color),
            makeVertex(tri.vertices[1], transform, ctx, color),
            makeVertex(tri.vertices[2], transform, ctx, color),
        };
        try self.vertices.appendSlice(self.allocator, &vertices);

        try self.draw_calls.append(self.allocator, .{
            .primitive_type = .triangle,
            .vertex_start = batch_offset,
            .vertex_count = 3,
        });
    }
    fn addRectangle(
        self: *GeometryBatch,
        rect: Rectangle,
        transform: ?Transform,
        ctx: RenderContext,
    ) !void {
        if (rect.fill_color == null) return; // TODO: Draw the outline

        const corners = rect.getCorners();
        const color = utils.colorToFloat(rect.fill_color.?);
        const batch_offset: u32 = @intCast(self.vertices.items.len);

        try self.vertices.ensureTotalCapacity(self.allocator, batch_offset + 6);
        try self.draw_calls.ensureTotalCapacity(self.allocator, self.draw_calls.items.len + 2);

        self.vertices.appendSliceAssumeCapacity(&.{
            makeVertex(corners[0], transform, ctx, color),
            makeVertex(corners[1], transform, ctx, color),
            makeVertex(corners[2], transform, ctx, color),
            makeVertex(corners[0], transform, ctx, color),
            makeVertex(corners[2], transform, ctx, color),
            makeVertex(corners[3], transform, ctx, color),
        });

        self.draw_calls.appendSliceAssumeCapacity(&.{
            .{ .primitive_type = .triangle, .vertex_start = batch_offset, .vertex_count = 3 },
            .{ .primitive_type = .triangle, .vertex_start = batch_offset + 3, .vertex_count = 3 },
        });
    }
    fn addPolygon(
        self: *GeometryBatch,
        poly: Polygon,
        transform: ?Transform,
        ctx: RenderContext,
    ) !void {
        if (poly.fill_color == null) return; // TODO: Draw the outline

        const batch_offset: u32 = @intCast(self.vertices.items.len);
        var tri_offset: u32 = 0;
        const color = utils.colorToFloat(poly.fill_color.?);
        const num_tris = poly.vertices.len;

        try self.vertices.ensureTotalCapacity(self.allocator, batch_offset + num_tris * 3);
        try self.draw_calls.ensureTotalCapacity(self.allocator, self.draw_calls.items.len + num_tris);

        for (0..num_tris) |i| {
            const v1 = poly.vertices[i];
            const v2 = poly.vertices[(i + 1) % num_tris];
            self.vertices.appendSliceAssumeCapacity(&.{
                makeVertex(poly.center, transform, ctx, color),
                makeVertex(v1, transform, ctx, color),
                makeVertex(v2, transform, ctx, color),
            });

            tri_offset = @intCast(i * 3);
            self.draw_calls.appendAssumeCapacity(.{
                .primitive_type = .triangle,
                .vertex_start = batch_offset + tri_offset,
                .vertex_count = 3,
            });
        }
    }
    fn addCircle(
        self: *GeometryBatch,
        circle: Circle,
        transform: ?Transform,
        ctx: RenderContext,
    ) !void {
        if (circle.fill_color == null) return; // TODO: Draw the outline

        const segments = 32; // TODO: adapt to screen space (16, 32, 64)
        const angle_step = std.math.tau / @as(f32, @floatFromInt(segments));
        const batch_offset: u32 = @intCast(self.vertices.items.len);
        const color = utils.colorToFloat(circle.fill_color.?);

        try self.vertices.ensureTotalCapacity(self.allocator, batch_offset + segments * 3);
        try self.draw_calls.ensureTotalCapacity(self.allocator, self.draw_calls.items.len + segments);

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

            self.vertices.appendSliceAssumeCapacity(&.{
                makeVertex(circle.origin, transform, ctx, color),
                makeVertex(p1, transform, ctx, color),
                makeVertex(p2, transform, ctx, color),
            });

            const i_u32: u32 = @intCast(i);
            self.draw_calls.appendAssumeCapacity(.{
                .primitive_type = .triangle,
                .vertex_start = batch_offset + i_u32 * 3,
                .vertex_count = 3,
            });
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
