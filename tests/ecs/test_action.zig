//! STUBBED for Phase 3 (open action registry).
//!
//! Every test below constructed the closed `ActionType` union
//! (`.action_type = .destroy_self`, `.{ .spawn_entity = ... }`, etc.), which
//! Phase 3 DELETES. The behaviors they asserted now live in the new suites:
//!   - action shape / decode / execute  → tests/ecs/test_action_registry.zig
//!   - builtin behavior (set_velocity, spawn, play_sound, priority)
//!                                       → tests/ecs/test_builtin_actions.zig
//!                                       → tests/ecs/test_action_executor.zig
//!
//! TODO(Phase 3): delete this file once the migration is complete, or re-home
//! any uniquely-valuable case below into the registry/builtin suites.

const std = @import("std");
const testing = std.testing;

test "Action suite is stubbed pending Phase 3 registry migration" {
    // placeholder so the suite compiles and reports a result; see the
    // commented original fixtures below for what needs re-homing.
    try testing.expect(true);
}

// ---------------------------------------------------------------------------
// ORIGINAL FIXTURES (Phase 3 will not compile these — kept as a migration map)
// ---------------------------------------------------------------------------
// const Action = @import("Action");
// const V2 = @import("math").V2;
//
// test "Action - destroy_self"   → registry: register/execute destroy_self
// test "Action - destroy_other"  → registry/executor: destroy_other arms
// test "Action - spawn_entity"   → builtin: spawn_entity (needs template mgr)
// test "Action - set_velocity self/other" → builtin: set_velocity
// test "Action - play_sound"     → builtin: play_sound (stub)
// test "Action - priority ordering / default priority"
//                                → executor: ascending-priority ordering test
// ---------------------------------------------------------------------------
