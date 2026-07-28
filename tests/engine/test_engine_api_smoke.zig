//! Phase F7 — public Engine API smoke test.
//!
//! The Engine struct exposes ~85 public methods, most "peeled" from EngineXxx.zig
//! files via `pub const foo = @import("EngineFoo.zig").foo`. Zig analyzes these
//! LAZILY: a peeled decl's body (and its signature types) is never type-checked
//! until something references it. So a wrapper can be broken — wrong import, a
//! type that no longer exists, a stale signature — and the engine still builds,
//! because no game happens to call it. (That's exactly how getCollisionEvents,
//! returning a nonexistent `math.Collision`, hid.)
//!
//! This test references EVERY public Engine method by name, forcing Zig to
//! resolve each one's type. A broken wrapper fails to compile HERE, naming
//! itself — turning silent rot into a loud, located test failure. No runtime
//! Engine is needed (none can exist headless): @TypeOf forces analysis without
//! a call. New public methods should be added to `api` below.

const std = @import("std");
const testing = std.testing;
const engine = @import("engine");
const Engine = engine.Engine;

// Every public method on Engine. Touching `@field(Engine, name)` forces Zig to
// analyze the (otherwise lazy) peeled wrapper and its signature.
const api = [_][]const u8{
    // lifecycle / loop (inline pub fns)
    "init",        "deinit",            "shouldClose",      "checkInternals",
    "update",      "tick",              "deltaTime",        "beginFrame",
    "endFrame",    "clear",             "fatal",
    // camera (EngineCamera.zig)
    "createCamera", "setActiveCamera",  "getActiveCamera",  "getActiveCameraTransform",
    "setCameraPosition", "setActiveCameraPosition", "translateCamera", "translateActiveCamera",
    "setCameraOrthoSize", "setActiveCameraOrthoSize", "zoomCameraInc", "zoomActiveCameraInc",
    "zoomCameraSmooth", "zoomActiveCameraSmooth",
    "setActiveCameraTrackingTarget", "enableActiveCameraTracking", "disableActiveCameraTracking",
    "setActiveCameraFollowStiffness", "setActiveCameraFollowDamping",
    // input (EngineInput.zig)
    "isDown", "isPressed", "isReleased", "getAxis", "getAxis2d", "getMouseScrollDelta",
    // bounds (EngineBounds.zig)
    "getGameWidth", "getGameHeight", "getTopLeft", "getTopRight", "getBottomLeft",
    "getBottomRight", "getCenter", "getLeftEdge", "getRightEdge", "getTopEdge",
    "getBottomEdge", "isInBounds", "wrapPosition",
    // world (EngineWorld.zig)
    "createEntity", "destroyEntity", "addComponent", "findEntityByTag",
    "findEntitiesByTag", "findEntitiesByPattern", "clearEntitiesByTag",
    // assets (EngineAssets.zig)
    "getFont",
    "getFontAtlasTexture",
    // collision (EngineCollision.zig) — getCollisionEvents was the known-broken one
    "clearCollisionEvents", "getCollisionEvents",
    // scene (EngineScene.zig)
    "loadScene", "loadTemplates", "setActiveScene", "instantiateActiveScene", "reloadActiveScene",
    // state (EngineState.zig)
    "declareStates", "declareChildren", "transitionTo", "pushState", "popState",
    "advanceState", "retreatState", "descendState", "ascendState", "restartState",
    "restartGame", "state", "getCurrentStateName", "setStateVar", "getStateVar",
    "stateEntered", "stateExited",
};

test "every public Engine method resolves (no rotted peeled wrappers)" {
    inline for (api) |name| {
        if (!@hasDecl(Engine, name)) {
            @compileError("Engine API smoke test lists '" ++ name ++ "' but Engine has no such decl");
        }
        // Force analysis of the (lazy) peeled wrapper. A broken signature/import
        // fails to compile here, naming the method.
        _ = @TypeOf(@field(Engine, name));
    }
}

test "the smoke list covers every public Engine decl (none silently un-tested)" {
    // The inverse guard: if someone adds a public method but forgets to list it
    // here, this fails — so the smoke test can't silently fall out of date.
    comptime {
        @setEvalBranchQuota(100000); // decls × api list is O(n*m) comptime branches
        for (@typeInfo(Engine).@"struct".decls) |decl| {
            const field = @field(Engine, decl.name);
            // only methods (callables); skip pub const TYPES re-exported on Engine
            // (e.g. StateDescriptor) and any pub data.
            if (@typeInfo(@TypeOf(field)) != .@"fn") continue;
            var found = false;
            for (api) |name| {
                if (std.mem.eql(u8, name, decl.name)) found = true;
            }
            if (!found) {
                @compileError("public Engine method '" ++ decl.name ++ "' is missing from the smoke-test api list");
            }
        }
    }
}
