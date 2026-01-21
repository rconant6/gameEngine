pub const Self = @This();
const std = @import("std");
const rend = @import("renderer");
const RenderContext = rend.RenderContext;
const Renderer = rend.Renderer;
const Circle = rend.Shapes.Circle;
const Line = rend.Shapes.Line;
const Rectangle = rend.Shapes.Rectangle;
const Triangle = rend.Shapes.Triangle;
const math = @import("math");
const V2 = math.V2;
const WorldPoint = math.WorldPoint;
const ShapeRegistry = rend.ShapeRegistry;
const draw = @import("DebugDraw.zig");
const DebugDraw = draw.DebugDraw;
const DebugArrow = draw.DebugArrow;
const DebugCircle = draw.DebugCircle;
const DebugLine = draw.DebugLine;
const DebugRect = draw.DebugRect;
const DebugText = draw.DebugText;
const assets = @import("assets");
const Font = assets.Font;

renderer: *Renderer,
default_font: *const Font,

pub fn init(renderer: *Renderer, default_font: *const Font) Self {
    return .{
        .renderer = renderer,
        .default_font = default_font,
    };
}

pub fn renderArrow(self: *Self, arrow: DebugArrow, ctx: RenderContext) void {
    const delta = arrow.end.sub(arrow.start);
    const direction = delta.normalize();
    const perpendicular = V2{ .x = -direction.y, .y = direction.x };

    const head_base = arrow.end.sub(direction.mul(arrow.head_size));
    const half_width = arrow.head_size * 0.65;

    const tip = arrow.end;
    const base_left = head_base.add(perpendicular.mul(half_width));
    const base_right = head_base.sub(perpendicular.mul(half_width));

    const line_geo = Line(WorldPoint){ .start = arrow.start, .end = head_base };
    self.renderer.drawGeometry(
        ShapeRegistry.createShapeUnion(Line(WorldPoint), line_geo),
        null,
        arrow.color,
        arrow.color,
        1,
        ctx,
    );
    const triangle_geo = Triangle(WorldPoint){ .v0 = tip, .v1 = base_right, .v2 = base_left };
    self.renderer.drawGeometry(
        ShapeRegistry.createShapeUnion(Triangle(WorldPoint), triangle_geo),
        null,
        null,
        arrow.color,
        1,
        ctx,
    );
}
pub fn renderCircle(self: *Self, circle: DebugCircle, ctx: RenderContext) void {
    const geo = rend.Shapes.Circle(WorldPoint){
        .origin = circle.origin,
        .radius = circle.radius,
    };
    self.renderer.drawGeometry(
        ShapeRegistry.createShapeUnion(Circle(WorldPoint), geo),
        null,
        if (circle.filled) circle.color else null,
        circle.color,
        1,
        ctx,
    );
}
pub fn renderLine(self: *Self, line: DebugLine, ctx: RenderContext) void {
    const geo = rend.Shapes.Line(WorldPoint){
        .start = line.start,
        .end = line.end,
    };
    self.renderer.drawGeometry(
        ShapeRegistry.createShapeUnion(Line(WorldPoint), geo),
        null,
        null,
        line.color,
        1,
        ctx,
    );
}
pub fn renderRect(self: *Self, rect: DebugRect, ctx: RenderContext) void {
    const half_w = (rect.max.x - rect.min.x) / 2;
    const half_h = (rect.max.y - rect.min.y) / 2;
    const center = rect.min.add(V2{ .x = half_w, .y = half_h });
    const geo = Rectangle(WorldPoint){
        .center = center,
        .half_width = half_w,
        .half_height = half_h,
    };
    self.renderer.drawGeometry(
        ShapeRegistry.createShapeUnion(Rectangle(WorldPoint), geo),
        null,
        if (rect.filled) rect.color else null,
        rect.color,
        1,
        ctx,
    );
}
pub fn renderText(self: *Self, text: DebugText, ctx: RenderContext) void {
    self.renderer.drawText(
        self.default_font,
        text.text,
        text.position,
        text.size,
        text.color,
        ctx,
    );
}

pub fn render(self: *Self, data: *const DebugDraw, ctx: RenderContext) void {
    for (data.arrows.items) |a| {
        if (a.cat.matches(data.visible_categories)) {
            self.renderArrow(a, ctx);
        }
    }
    for (data.circles.items) |c| {
        if (c.cat.matches(data.visible_categories)) {
            self.renderCircle(c, ctx);
        }
    }
    for (data.lines.items) |l| {
        if (l.cat.matches(data.visible_categories)) {
            self.renderLine(l, ctx);
        }
    }
    for (data.rects.items) |r| {
        if (r.cat.matches(data.visible_categories)) {
            self.renderRect(r, ctx);
        }
    }
    for (data.texts.items) |t| {
        if (t.cat.matches(data.visible_categories)) {
            self.renderText(t, ctx);
        }
    }
}
