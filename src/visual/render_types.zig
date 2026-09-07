const math = @import("math");
const V2 = math.V2;
const WorldPoint = math.WorldPoint;
const col = @import("color.zig");
const Color = col.Color;
const ShapeData = @import("shape_data.zig").ShapeData;

pub const CoordinateSpace = enum { world, screen };

// Backend-agnostic texture formats. The engine speaks these; each backend maps
// them to its native type at its own boundary (no MTL*/VK* above the backend).
pub const PixelFormat = enum { r8, rgba8, bgra8_srgb };

pub const DrawStyle = struct {
    fill: ?Color = null,
    stroke: ?Color = null,
    stroke_width: f32 = 1.0, // world units world-side, px screen-side
    opacity: f32 = 1.0,
    gradient: ?Gradient = null,

    // The effective fill color: an explicit `fill`, or (if only a gradient is
    // set) the gradient's start color as the trigger/fallback. So a gradient
    // renders even without an explicit fill — no silent no-op. null = no fill.
    pub fn fillColor(self: DrawStyle) ?Color {
        return self.fill orelse if (self.gradient) |g| g.start_color else null;
    }

    pub inline fn draws(self: DrawStyle) bool {
        return self.fillColor() != null or self.stroke != null;
    }
};

pub const Gradient = struct {
    kind: enum { linear, radial },
    start_color: Color,
    end_color: Color,
    angle: f32 = 0, // linear only: axis direction in shape-local space (radians)
};

pub const Transform = struct {
    offset: ?WorldPoint = null,
    rotation: ?f32 = null,
    scale: ?f32 = null,
};

pub const ScreenAnchor = enum {
    TopLeft,
    TopCenter,
    TopRight,
    BottomLeft,
    BottomCenter,
    BottomRight,
    MiddleLeft,
    MiddleCenter,
    MiddleRight,
};
/// ctx: any struct with `width: u32` and `height: u32`.
/// anytype because RenderContext lives in `renderer` — visual cannot name it.
pub fn getAnchorPosition(anchor: ScreenAnchor, ctx: anytype) V2 {
    const f_width: f32 = @floatFromInt(ctx.width);
    const f_height: f32 = @floatFromInt(ctx.height);
    return switch (anchor) {
        .TopLeft => .{ .x = 0, .y = 0 },
        .TopCenter => .{ .x = f_width / 2, .y = 0 },
        .TopRight => .{ .x = f_width, .y = 0 },
        .BottomLeft => .{ .x = 0, .y = f_height },
        .BottomCenter => .{ .x = f_width / 2, .y = f_height },
        .BottomRight => .{ .x = f_width, .y = f_height },
        .MiddleLeft => .{ .x = 0, .y = f_height / 2 },
        .MiddleCenter => .{ .x = f_width / 2, .y = f_height / 2 },
        .MiddleRight => .{ .x = f_width, .y = f_height / 2 },
    };
}

/// One drawable unit. text / sprite / debug / widget are all the same thing at
/// draw time — geometry + where + how + which projection. Every producer builds
/// one and hands it to `render()`; the renderer has a single path. `space` lives
/// HERE (the conduit); an entity's stored copy is `Sprite.space`. Transient —
/// built per draw, consumed immediately, no lifetime/allocation.
pub const Renderable = struct {
    shape: ShapeData,
    transform: ?Transform = null,
    style: DrawStyle = .{},
    space: CoordinateSpace = .world,
    layer: i32 = 0, // band + z_order
    texture: ?*anyopaque = null, // null => {0, 0}
    uv: ?[4][2]f32 = null, // null => {0, 0}
    sdf: bool = false,
};
