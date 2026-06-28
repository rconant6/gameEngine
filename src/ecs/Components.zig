const std = @import("std");
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
const action = @import("action");

// MARK: Action Components (defined in action module, re-exported for ECS use)
pub const OnCollision = action.OnCollision;
pub const OnInput = action.OnInput;
pub const OnTimer = action.OnTimer;

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
    font_name: []const u8 = "__default__",
    size: f32,
    text_color: Color,
    // Ownership of the two string fields, tracked separately. Scene-instantiated
    // Text dupes both (the AST is not a durable owner); code-created Text with
    // literals leaves both false and is never freed. StateTextSys takes over
    // `text` (pointing it into its own buf) and flips text_owned=false after
    // freeing the prior owned copy — see StateTextSys.run.
    text_owned: bool = false,
    font_owned: bool = false,

    pub fn deinit(self: *Text, gpa: std.mem.Allocator) void {
        if (self.text_owned) gpa.free(self.text);
        if (self.font_owned) gpa.free(self.font_name);
    }
};

pub const StateText = struct {
    key: []const u8,
    prefix: []const u8 = "",
    buf: [64]u8 = undefined,
    len: usize = 0,
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
    solid: bool = false,
};

// MARK: Generic Game Components
pub const Lifetime = struct {
    remaining: f32, // seconds
};
pub const Health = struct {
    remaining: i32,
};
pub const Tag = @import("Tag.zig");

// MARK: Sprite Components
pub const ZxlSprite = struct {
    asset_name: []const u8, // matches name from [X:asset zxl] in scene file
    current_frame: u16 = 0, // which animation frame to show
    pixel_scale: f32 = 1.0, // world-units per pixel
    flip_h: bool = false, // mirror horizontally
    flip_v: bool = false, // mirror vertically
    visible: bool = true,
    playing: bool = true, // advance animation each frame
    elapsed_ms: f32 = 0, // accumulator for frame timing
    // asset_name is a borrowed AST slice when scene-instantiated; dupe + own so
    // it survives the scene's lifetime. Code-created leaves it false.
    asset_name_owned: bool = false,

    pub fn deinit(self: *ZxlSprite, gpa: std.mem.Allocator) void {
        if (self.asset_name_owned) gpa.free(self.asset_name);
    }
};

// MARK: Tagging Comonents
pub const ScreenSpace = struct { _dummy: u8 = 0 };
pub const Destroy = struct { _dummy: u8 = 0 };
pub const ActiveCamera = struct { _dummy: u8 = 0 };
pub const MinimapCamera = struct { _dummy: u8 = 0 };
