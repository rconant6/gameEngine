//! STUBBED for Phase 3 (open action registry).
//!
//! The CollisionTrigger STRUCTURE survives Phase 3, but every fixture here had
//! to construct `Action` values — and the Action shape itself changes in
//! Phase 3 (id + fn-pointers, no ActionType union), so these can't be rebuilt
//! until the new types exist. Coverage now lives in:
//!   - oriented-normal / process() behavior → tests/ecs/test_reflect_velocity.zig
//!   - tag pattern matching                 → tests/ecs/test_tag.zig (Tag.matchesPattern)
//!   - action decode/execute payloads       → tests/ecs/test_action_registry.zig
//!
//! TODO(Phase 3): rebuild structural construction tests against the new Action
//! shape, or delete this file if the coverage above is deemed sufficient.

const std = @import("std");
const testing = std.testing;

test "CollisionTrigger suite is stubbed pending Phase 3 Action-shape change" {
    try testing.expect(true);
}
