const V2 = @import("math").V2;
const Entity = @import("Entity.zig");

pub const Collision = struct {
    entity_a: Entity,
    entity_b: Entity,
    point: V2,
    normal: V2,
    penetration: f32,
    actions_fired: bool = false,
};
