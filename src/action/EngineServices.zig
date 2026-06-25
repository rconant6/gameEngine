//! Capability surface handed to action handlers so they can reach GAME state
//! (score, lives, scene flow) without the `action` module importing `engine`.
//!
//! `ctx` is an erased `*Engine` — unnameable here because action can't import
//! engine. The engine populates the vtable with thunks that cast `ctx` back to
//! `*Engine` on its own side of the boundary (see EngineState.zig). Handlers
//! call the typed wrappers below; the vtable/anyopaque plumbing stays hidden.

const game_state = @import("game_state");
const StateValue = game_state.StateValue;

pub const EngineServices = struct {
    ctx: *anyopaque, // *Engine, erased across the module boundary
    vtable: *const VTable,

    pub const VTable = struct {
        set_state_var: *const fn (*anyopaque, []const u8, StateValue) anyerror!void,
        get_state_var: *const fn (*anyopaque, []const u8) ?StateValue,
        transition_to: *const fn (*anyopaque, []const u8) void,
        restart_state: *const fn (*anyopaque) void,
        restart_game: *const fn (*anyopaque, []const u8) void,
    };

    // Thin typed wrappers — the only thing handlers should touch.
    pub fn setStateVar(self: EngineServices, key: []const u8, val: StateValue) !void {
        return self.vtable.set_state_var(self.ctx, key, val);
    }
    pub fn getStateVar(self: EngineServices, key: []const u8) ?StateValue {
        return self.vtable.get_state_var(self.ctx, key);
    }
    pub fn transitionTo(self: EngineServices, name: []const u8) void {
        self.vtable.transition_to(self.ctx, name);
    }
    pub fn restartState(self: EngineServices) void {
        self.vtable.restart_state(self.ctx);
    }
    pub fn restartGame(self: EngineServices, name: []const u8) void {
        self.vtable.restart_game(self.ctx, name);
    }
};
