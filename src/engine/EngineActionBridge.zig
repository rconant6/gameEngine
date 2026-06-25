const EngineServices = @import("action").EngineServices;
const Engine = @import("Engine.zig").Engine;
const StateValue = @import("game_state").StateValue;
const log = @import("debug").log;

// MARK: EngineServices vtable thunks
fn svcSetStateVar(ctx: *anyopaque, name: []const u8, val: StateValue) anyerror!void {
    const eng: *Engine = @ptrCast(@alignCast(ctx));
    try eng.setStateVar(name, val);
}
fn svcGetStateVar(ctx: *anyopaque, name: []const u8) ?StateValue {
    const eng: *Engine = @ptrCast(@alignCast(ctx));
    return eng.getStateVar(name);
}
fn svcRestartState(ctx: *anyopaque) void {
    const eng: *Engine = @ptrCast(@alignCast(ctx));
    eng.restartState();
}
fn svcTransitionTo(ctx: *anyopaque, name: []const u8) void {
    const eng: *Engine = @ptrCast(@alignCast(ctx));
    const node = eng.state_manager.findByName(name) orelse {
        log.err(.engine, "transition_state: unknown state '{s}'", .{name});
        return;
    };
    eng.state_manager.queueAction(.{ .transition_to_node = node });
}
fn svcRestartGame(ctx: *anyopaque, name: []const u8) void {
    const eng: *Engine = @ptrCast(@alignCast(ctx));
    const node = eng.state_manager.findByName(name) orelse {
        log.err(.engine, "restart_game: unknown state '{s}'", .{name});
        return;
    };
    eng.state_manager.queueAction(.{ .restart_game_node = node });
}

pub const services_vtable = EngineServices.VTable{
    .set_state_var = svcSetStateVar,
    .get_state_var = svcGetStateVar,
    .restart_state = svcRestartState,
    .transition_to = svcTransitionTo,
    .restart_game = svcRestartGame,
};
