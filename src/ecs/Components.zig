const core = @import("core");
const V2 = core.V2;

const rend = @import("renderer");
const Color = rend.Color;
const Shape = rend.Shape;

const asset = @import("asset");
const FontHandle = asset.FontHandle;

// MARK: Spatial Components
pub const Transform = struct {
    position: V2,
    rotation: f32,
    scale: f32,
};
pub const Velocity = struct {
    linear: V2,
    angular: f32,
};

// MARK: Rendering Components
pub const Sprite = struct {
    geometry: Shape,
    fill_color: ?Color = null,
    stroke_color: ?Color = null,
    stroke_width: f32 = 1,
    visible: bool = true,

    pub fn deinit(self: *Sprite) void {
        self.geometry.deinit();
    }
};
pub const Text = struct {
    text: []const u8,
    font: FontHandle,
    scale: f32,
    color: Color,
};
pub const RenderLayer = struct {
    z_order: i32 = 0,
};

// MARK: Physics Components
pub const CircleCollider = struct {
    radius: f32,
};
pub const RectCollider = struct {
    half_width: f32,
    half_height: f32,
};

// MARK: Utility Components
pub const Lifetime = struct {
    remaining: f32, // seconds
};

// MARK: Tagging Comonents
pub const ScreenWrap = struct { _dummy: u8 = 0 };
pub const ScreenClamp = struct { _dummy: u8 = 0 };
pub const Destroy = struct { _dummy: u8 = 0 };
