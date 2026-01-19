const Entity = @import("Entity.zig");
const core = @import("math");
const V2 = core.V2;

pub const TrackingMode = packed struct {
    enabled: bool = true,

    immediate: bool = false,
    smooth: bool = true,

    lead_horizontal: bool = false,
    lead_vertical: bool = false,
    predict_motion: bool = false,

    lock_x: bool = false,
    lock_y: bool = false,

    use_deadzone: bool = false,
    auto_zoom: bool = false,
    enable_shake: bool = false,
};

pub const CameraTracking = struct {
    target: ?Entity = null,
    target_offset: V2 = .ZERO,

    mode: TrackingMode = .{},

    follow_stiffness: V2 = .ZERO,
    follow_damping: V2 = .ZERO,

    lead_distance: V2 = .ZERO,
    lead_smoothing: f32 = 0,
    lead_speed_threshold: f32 = 0,

    current_lead_offset: V2 = .ZERO,
    velocity_tracker: V2 = .ZERO,
    last_target_position: V2 = .ZERO,
};
