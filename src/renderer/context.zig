const math = @import("math");
const WorldPoint = math.WorldPoint;

pub const RendererConfig = struct {
    width: u32,
    height: u32,

    native_handle: ?*anyopaque = null,
    enable_validation: bool = false,
    vsync: bool = true,
    msaa_samples: u8 = 4,
};

/// The engine's own render context. Renderer entry points take `ctx: anytype`
/// and read only `width`, `height`, `camera_loc`, `ortho_size` — this struct is
/// one shape that satisfies that contract, not a type anyone is required to use.
/// An app may pass its own struct with extra fields (shake offset, time-of-day).
pub const RenderContext = struct {
    width: u32,
    height: u32,
    camera_loc: WorldPoint,
    ortho_size: f32,

    scale_factor: f32 = 1.0,
    frame_number: u64 = 0,

    time: f64 = 0,
    delta_time: f64 = 0,
};
