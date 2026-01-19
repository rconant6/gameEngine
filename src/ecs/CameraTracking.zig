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
    target: ?Entity,
    target_offset: V2,

    mode: TrackingMode,

    follow_stiffness: V2,
    follow_damping: V2,

    lead_distance: V2,
    lead_smoothing: f32,
    lead_speed_threshold: f32,

    current_lead_offset: V2,
    velocity_tracker: V2,
    last_taget_position: V2,
};
