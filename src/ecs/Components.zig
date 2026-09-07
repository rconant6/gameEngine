const std = @import("std");
const math = @import("math");
const V2 = math.V2;
const registry = @import("registry");
const ColliderData = registry.ColliderData;
// ShapeData comes from `visual` (geometry vocabulary), not the registry shim.
const visual = @import("visual");
const ShapeData = visual.ShapeData;
const ScreenAnchor = visual.ScreenAnchor;
const Color = visual.Color;
const Colors = visual.Colors;
const CoordinateSpace = visual.CoordinateSpace;
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
    opacity: f32 = 1.0,
    stroke_width: f32 = 1,
    space: CoordinateSpace = .world,
    visible: bool = true,
    tint: Color = Colors.WHITE,

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
pub const TextAlign = enum { left, center, right };

pub const Text = struct {
    text: []const u8,
    font_name: []const u8 = "__default__",
    size: f32,
    text_color: Color,
    alignment: TextAlign = .left,
    // Ownership of the two string fields, tracked separately. Scene-instantiated
    // Text dupes both (the AST is not a durable owner); code-created Text with
    // literals leaves both false and is never freed. StateTextSys takes over
    // `text` (pointing it into its own buf) and flips text_owned=false after
    // freeing the prior owned copy — see StateTextSys.run.
    text_owned: bool = false,
    font_owned: bool = false,

    pub fn alignOffsetX(self: Text, measured_width: f32) f32 {
        return switch (self.alignment) {
            .left => 0,
            .center => -measured_width / 2.0,
            .right => -measured_width,
        };
    }

    pub fn deinit(self: *Text, persistent: std.mem.Allocator) void {
        if (self.text_owned) persistent.free(self.text);
        if (self.font_owned) persistent.free(self.font_name);
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
    mass: f32 = 1.0, // 0 = static/immovable object
    friction: f32 = 0.0, // linear damping coefficient
    restitution: f32 = 1.0, // Bounciness [0..1]
    gravity_scale: f32 = 0.0, // multiplier of world gravity
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
    tint: Color = Colors.WHITE,

    pub fn deinit(self: *ZxlSprite, persistent: std.mem.Allocator) void {
        if (self.asset_name_owned) persistent.free(self.asset_name);
    }
};

// MARK: Tagging Comonents
pub const ScreenSpace = struct { _dummy: u8 = 0 };
pub const Destroy = struct { _dummy: u8 = 0 };
pub const ActiveCamera = struct { _dummy: u8 = 0 };
pub const MinimapCamera = struct { _dummy: u8 = 0 };
