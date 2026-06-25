//! STUBBED for Phase 3 (open action registry).
//!
//! The InputTrigger STRUCTURE (input: union{key,mouse}, actions slice) survives
//! Phase 3, but every fixture here had to construct `Action` values, and the
//! Action shape changes in Phase 3 (id + fn-pointers, no ActionType union) — so
//! these can't be rebuilt until the new types exist.
//!
//! Phase 4B is the natural home for the *real* InputTrigger tests: drive
//! InputTrigger.process() with frame input snapshots and assert pressed/held/
//! released phase firing. Action decode/execute lives in test_action_registry.zig.
//!
//! TODO(Phase 4B): rebuild as process()-driven phase tests against the new
//! Action shape.

const std = @import("std");
const testing = std.testing;

test "InputTrigger suite is stubbed pending Phase 3 Action-shape change" {
    try testing.expect(true);
}
