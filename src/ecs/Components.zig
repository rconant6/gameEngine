const math = @import("math");
const V2 = math.V2;
const registry = @import("registry");
const ColliderData = registry.ColliderData;
const ShapeRegistry = registry.ShapeRegistry;
const ShapeData = registry.ShapeData;
const rend = @import("renderer");
const ScreenAnchor = rend.ScreenAnchor;
const Color = rend.Color;
const Shape = rend.Shape;
const asset = @import("assets");
const FontHandle = asset.FontHandle;
const action = @import("action");

// MARK: Action Components (defined in action module, re-exported for ECS use)
pub const OnCollision = action.OnCollision;
pub const OnInput = action.OnInput;

// MARK: Spatial Components
pub const Transform = struct {
    position: V2 = .ZERO,
    rotation: f32 = 0,
    scale: f32 = 1,
};

// MARK: Camera Components
pub const Camera = @import("Camera.zig");
const ct = @import("CameraTracking.zig");
pub const CameraTracking = ct.CameraTracking;
// MARK: Rendering Components
pub const Sprite = struct {
    geometry: ?ShapeData,
    fill_color: ?Color = null,
    stroke_color: ?Color = null,
    stroke_width: f32 = 1,
    visible: bool = true,

    pub fn deinit(self: *Sprite) void {
        if (self.geometry) |*geo| {
            switch (geo.*) {
                inline else => |*shape| {
                    if (@hasDecl(@TypeOf(shape.*), "deinit"))
                        shape.deinit();
                },
            }
        }
    }
};
pub const Text = struct {
    text: []const u8,
    font_asset: FontHandle,
    size: f32,
    text_color: Color,
};
pub const RenderLayer = struct {
    z_order: i32 = 0,
};
pub const UIElement = struct {
    anchor: ScreenAnchor,
    offset: V2,
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
pub const Collider = struct {
    collider: ColliderData,
};

// MARK: Generic Game Components
pub const Lifetime = struct {
    remaining: f32, // seconds
};
pub const Health = struct {
    remaining: i32,
};
pub const Tag = @import("Tag.zig");

// MARK: Tagging Comonents
pub const ScreenSpace = struct { _dummy: u8 = 0 };
pub const Destroy = struct { _dummy: u8 = 0 };
pub const ActiveCamera = struct { _dummy: u8 = 0 };
pub const MinimapCamera = struct { _dummy: u8 = 0 };
