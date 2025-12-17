const rend = @import("renderer");
const Color = rend.Color;
const Shape = rend.Shape;
const Transform = rend.Transform;
const core = @import("core");
const V2 = core.V2;

pub const TextComp = struct {
    char: u8 = 0,
};

pub const PlayerComp = struct {
    playerID: u8 = 0,
};

pub const Sprite = struct {
    color: Color,
    outline_color: ?Color = null,
    shape: Shape,
};

pub const ControlComp = struct {
    rotationRate: ?f32 = null,
    thrustForce: ?f32 = null,
    shotRate: ?f32 = null,
};

pub const TransformComp = struct {
    transform: Transform,
};

pub const RenderComp = struct {
    shape: Shape,
    visible: bool,
};

pub const VelocityComp = struct {
    velocity: V2 = V2.ZERO,
};
