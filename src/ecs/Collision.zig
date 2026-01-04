pub const Self = @This();
const V2 = @import("core").V2;
const Entity = @import("Entity.zig");

entity_a: Entity,
entity_b: Entity,
point: V2,
normal: V2,
penetration: f32,
actions_fired: bool = false,
