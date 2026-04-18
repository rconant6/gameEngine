const assets = @import("assets");
const Font = assets.Font;
const rend = @import("renderer");
const Color = rend.Color;
const Colors = rend.Colors;
const ColorLibrary = rend.ColorLibrary;
const Renderer = rend.Renderer;
const RenderContext = rend.RenderContext;
const Rect = @import("Rect.zig");
const V2 = @import("math").V2;

/// Used to pass required info to widgets for layout purposes
pub const LayoutInfo = struct {
    // Required for widgets with text
    font: *const Font,
    // Required for all widgets
    constraints: Constraints,
    pos: V2,
};
/// Used to pass required info to widgets for rendering purposes
pub const RenderInfo = struct {
    renderer: *Renderer,
    ctx: RenderContext,
    font: *const Font,
    bounds: Rect,
};

pub const Size = struct {
    width: f32,
    height: f32,

    pub const zero = Size{ .width = 0, .height = 0 };

    pub fn constrain(self: Size, c: Constraints) Size {
        return .{
            .width = @max(c.min_width, @min(c.max_width, self.width)),
            .height = @max(c.min_height, @min(c.max_height, self.height)),
        };
    }
};

pub const EdgeInsets = struct {
    top: f32,
    right: f32,
    bottom: f32,
    left: f32,

    pub fn all(val: f32) EdgeInsets {
        return .{
            .top = val,
            .right = val,
            .bottom = val,
            .left = val,
        };
    }
    pub fn symmetric(hor: f32, vert: f32) EdgeInsets {
        return .{
            .left = hor,
            .right = hor,
            .top = vert,
            .bottom = vert,
        };
    }

    pub fn horizontal(self: EdgeInsets) f32 {
        return self.left + self.right;
    }
    pub fn vertical(self: EdgeInsets) f32 {
        return self.top + self.bottom;
    }
};

pub const Constraints = struct {
    min_width: f32,
    max_width: f32,
    min_height: f32,
    max_height: f32,

    pub fn tight(w: f32, h: f32) Constraints {
        return .{
            .min_width = w,
            .max_width = w,
            .min_height = h,
            .max_height = h,
        };
    }
    pub fn loose(w: f32, h: f32) Constraints {
        return .{
            .min_width = 0,
            .max_width = w,
            .min_height = 0,
            .max_height = h,
        };
    }
    pub fn deflate(self: Constraints, insets: EdgeInsets) Constraints {
        return .{
            .min_width = @max(0, self.min_width - insets.horizontal()),
            .max_width = @max(0, self.max_width - insets.horizontal()),
            .min_height = @max(0, self.min_height - insets.vertical()),
            .max_height = @max(0, self.max_height - insets.vertical()),
        };
    }
};
