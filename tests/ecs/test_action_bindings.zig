//! STUBBED for Phase 3 (open action registry).
//!
//! ActionBindings (the generic trigger container behind OnInput / OnCollision)
//! survives Phase 3 unchanged, but the fixtures here construct `Action` values,
//! and the Action shape changes in Phase 3 (id + fn-pointers, no ActionType
//! union) — so the generic can't be exercised here until the new types exist.
//!
//! TODO(Phase 3): rebuild the four generic tests (instantiation, hasTriggers,
//! multiple triggers, trigger-with-multiple-actions) using a placeholder Action
//! of the new shape once Action.Action is finalized. The generic itself needs
//! no change — only the embedded Action values do.

const std = @import("std");
const testing = std.testing;

test "ActionBindings suite is stubbed pending Phase 3 Action-shape change" {
    try testing.expect(true);
}
