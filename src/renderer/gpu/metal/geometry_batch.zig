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
            .draw_call = .empty,
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

    pub fn getVertexSlice(self: *const GeometryBatch) []const Vertex {
        return self.vertices.items;
    }

    pub fn addShape(
        self: *GeometryBatch,
        shape: ShapeData,
        transform: ?Transform,
        ctx: *const RenderContext,
    ) !void {
        switch (shape) {
            .Rectangle => |rect| try addRectangle(self, rect, transform, ctx),
            // TODO: need to add the rest
            else => unreachable,
        }
    }

    fn addLine(
        batch: *GeometryBatch,
        line: Line,
        transform: ?Transform,
        ctx: RenderContext,
    ) !void {
        if (line.color == null) return;

        const start_vertex_idx: u32 = @intCast(batch.vertices.items.len);

        const start = if (transform) |t|
            utils.transformPoint(line.start, t)
        else
            line.start;
        const end = if (transform) |t|
            utils.transformPoint(line.end, t)
        else
            line.end;

        const start_screen = utils.gameToScreenF32(start, ctx);
        const end_screen = utils.gameToScreenF32(end, ctx);

        const color = utils.colorToFloat(line.color.?);

        try batch.vertices.append(.{ .position = start_screen, .color = color });
        try batch.vertices.append(.{ .position = end_screen, .color = color });

        try batch.draw_calls.append(.{
            .primitive_type = .line,
            .vertex_start = start_vertex_idx,
            .vertex_count = 2,
        });
    }
    fn addTriangle(
        batch: *GeometryBatch,
        tri: Triangle,
        transform: ?Transform,
        ctx: RenderContext,
    ) !void {
        if (tri.fill_color == null) return; // TODO: Draw the outline

        const start_vertex_idx: u32 = @intCast(batch.vertices.items.len);
        const color = utils.colorToFloat(tri.fill_color.?);

        for (tri.vertices) |vertex| {
            const transformed = if (transform) |t|
                utils.transformPoint(vertex, t)
            else
                vertex;

            const screen_pos = utils.gameToScreenF32(transformed, ctx);

            try batch.vertices.append(.{
                .position = screen_pos,
                .color = color,
            });
        }

        try batch.draw_calls.append(.{
            .primitive_type = .triangle,
            .vertex_start = start_vertex_idx,
            .vertex_count = 3,
        });
    }
    fn addRectangle(
        self: *GeometryBatch,
        shape: ShapeData,
        transform: ?Transform,
        ctx: *const RenderContext,
    ) !void {
        _ = self;
        _ = shape;
        _ = transform;
        _ = ctx;
    }
    fn addCircle(
        self: *GeometryBatch,
        shape: ShapeData,
        transform: ?Transform,
        ctx: *const RenderContext,
    ) !void {
        _ = self;
        _ = shape;
        _ = transform;
        _ = ctx;
    }
    fn addEllipse(
        self: *GeometryBatch,
        shape: ShapeData,
        transform: ?Transform,
        ctx: *const RenderContext,
    ) !void {
        _ = self;
        _ = shape;
        _ = transform;
        _ = ctx;
    }
};
