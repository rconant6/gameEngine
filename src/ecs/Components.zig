const core = @import("core");
const V2 = core.V2;

const rend = @import("renderer");
const Color = rend.Color;
const Shape = rend.Shape;

const asset = @import("asset");
const FontHandle = asset.FontHandle;
const collider = @import("collider.zig");

// MARK: Spatial Components
pub const Transform = struct {
    position: V2,
    rotation: f32,
    scale: f32,
};

// MARK: Rendering Components
pub const Sprite = struct {
    geometry: ?Shape,
    fill_color: ?Color = null,
    stroke_color: ?Color = null,
    stroke_width: f32 = 1,
    visible: bool = true,

    pub fn deinit(self: *Sprite) void {
        if (self.geometry) |*g| g.deinit();
    }
};
pub const Text = struct {
    text: []const u8,
    font_asset: FontHandle,
    size: f32,
    text_color: Color,
};
pub const Box = struct {
    size: V2,
    fill_color: ?Color = null,
    filled: bool,
};
pub const Camera = struct {
    fov: f32,
    near: f32,
    far: f32,
};
pub const RenderLayer = struct {
    z_order: i32 = 0,
};

// MARK: Physics Components
pub const Velocity = struct {
    linear: V2,
    angular: f32,
};
pub const Physics = struct {
    mass: f32,
    friction: f32,
};
// MARK: Collision Components
pub const Collider = collider.Collider;

// MARK: Utility Components
pub const Lifetime = struct {
    remaining: f32, // seconds
};

// MARK: Tagging Comonents
pub const ScreenWrap = struct { _dummy: u8 = 0 };
pub const ScreenClamp = struct { _dummy: u8 = 0 };
pub const Destroy = struct { _dummy: u8 = 0 };
