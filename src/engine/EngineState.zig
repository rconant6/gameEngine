const std = @import("std");
const Engine = @import("Engine.zig").Engine;
const gsm = @import("game_state");
const GameStateManager = gsm.GameStateManager;
const StateValue = gsm.StateValue;
const StateDescriptor = gsm.StateDescriptor;
const log = @import("debug").log;

pub fn declareStates(
    self: *Engine,
    comptime S: type,
    descriptors: anytype,
) !void {
    inline for (std.meta.fields(S)) |field| {
        const d: StateDescriptor = @field(descriptors, field.name);
        _ = self.state_manager.declareRoot(field.name, d) catch {
            log.fatal(
                .engine,
                "Unable to declare Game States: {s}",
                .{@typeName(S)},
            );
        };
    }
}

pub fn declareChildren(
    self: *Engine,
    comptime C: type,
    comptime P: type,
    parent: P,
    descriptors: anytype,
) !void {
    const parent_node = self.state_manager.findByName(@tagName(parent)) orelse {
        log.fatal(.engine, "Parent state not declared: {s}", .{@tagName(parent)});
        return;
    };
    inline for (std.meta.fields(C)) |c_field| {
        const d: StateDescriptor = @field(descriptors, c_field.name);
        _ = self.state_manager.declareChild(c_field.name, parent_node, d) catch {
            log.fatal(
                .engine,
                "Unable to add ContentLayers: {s} to ParentState {s}",
                .{ @typeName(C), @typeName(P) },
            );
        };
    }
}

pub fn transitionTo(
    self: *Engine,
    comptime S: type,
    s: S,
) !void {
    self.state_manager.queueAction(.{ .transition_to = @tagName(s) });
}

pub fn pushState(
    self: *Engine,
    comptime S: type,
    s: S,
) void {
    const node = self.state_manager.findByName(@tagName(s)) orelse {
        log.err(.engine, "pushState: unknown state '{s}'", .{@tagName(s)});
        return;
    };
    self.state_manager.queueAction(.{ .push = node });
}

pub fn popState(self: *Engine) void {
    self.state_manager.queueAction(.pop);
}

pub fn advanceState(self: *Engine) void {
    self.state_manager.queueAction(.advance);
}

pub fn retreatState(self: *Engine) void {
    self.state_manager.queueAction(.goback);
}

pub fn descendState(self: *Engine) void {
    self.state_manager.queueAction(.descend);
}

pub fn ascendState(self: *Engine) void {
    self.state_manager.queueAction(.ascend);
}

pub fn restartState(self: *Engine) void {
    self.state_manager.queueAction(.restart_state);
}

pub fn restartGame(
    self: *Engine,
    comptime S: type,
    s: S,
) void {
    self.state_manager.queueAction(.{ .restart_game = @tagName(s) });
}

pub fn state(
    self: *Engine,
    comptime S: type,
) ?S {
    const current = self.state_manager.current orelse return null;
    return std.meta.stringToEnum(S, current.name);
}

pub fn getCurrentStateName(self: *Engine) ?[]const u8 {
    const current = self.state_manager.current orelse return null;
    return current.name;
}

pub fn setStateVar(
    self: *Engine,
    key: []const u8,
    val: StateValue,
) !void {
    try self.state_manager.setStateVar(key, val);
}

pub fn getStateVar(
    self: *Engine,
    key: []const u8,
) ?StateValue {
    return self.state_manager.getStateVar(key);
}
