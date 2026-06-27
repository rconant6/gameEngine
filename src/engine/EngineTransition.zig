const std = @import("std");
const ArrayList = std.ArrayList;
const Engine = @import("Engine.zig").Engine;
const ecs = @import("ecs");
const gsm = @import("game_state");
const TransitionResult = gsm.TransitionResult;
const log = @import("debug").log;

pub fn applyStateTransition(self: *Engine, result: TransitionResult) void {
    switch (result.kind) {
        .pop => destroyTopOverlayBatch(self),
        .push => if (result.scene) |scene_name| instantiateOverlay(self, scene_name) catch |err| {
            log.err(
                .engine,
                "Unable to instantiate overlay {s}  {any}",
                .{ scene_name, err },
            );
        },
        else => {
            if (result.world_policy == .clear) {
                self.world.destroyAllExcept(self.active_camera_entity);
                clearAllOverlayBatches(self); // batches are stale (world is gone)
            }
            if (result.scene) |scene_name| {
                const active_name = self.scene_manager.active_scene_name;
                const switching = active_name == null or !std.mem.eql(u8, scene_name, active_name.?);
                const need = switching or result.world_policy == .clear or result.kind == .restart;
                if (need) {
                    if (switching) self.scene_manager.setActiveScene(scene_name) catch |err| {
                        log.err(
                            .scene,
                            "Unable to set scene: {s}   {any}",
                            .{ scene_name, err },
                        );
                        return;
                    };
                    // A .clear already wiped the world; otherwise tear down the
                    // previous base scene's entities so a same-world switch (or a
                    // restart re-entering the same scene) doesn't leak the old set.
                    if (result.world_policy != .clear) {
                        self.instantiator.clearLastInstantiated(&self.world);
                    }
                    self.instantiateActiveScene() catch |err| {
                        log.err(
                            .scene,
                            "Unable to instantiate scene: {s}   {any}",
                            .{ scene_name, err },
                        );
                    };
                }
            }
        },
    }

    self.active_systems = result.systems;
}

fn instantiateOverlay(self: *Engine, scene_name: []const u8) !void {
    const scene_file = self.scene_manager.getScene(scene_name) orelse {
        log.err(.engine, "Scene {s} does not exist", .{scene_name});
        try self.overlay_batches.append(self.mem.persistent, &.{});
        return error.OverlaySceneDoesNotExist;
    };

    self.instantiator.instantiate(scene_file) catch |err| {
        log.err(.scene, "Unable to instantiate {s} {any}", .{ scene_name, err });
        return;
    };

    const new_entities = self.instantiator.last_instantiated_entities.items;
    const batch = try self.mem.persistent.dupe(ecs.Entity, new_entities);
    try self.overlay_batches.append(self.mem.persistent, batch);
}

fn destroyTopOverlayBatch(self: *Engine) void {
    const batch = self.overlay_batches.pop() orelse return;
    for (batch) |e| self.world.destroyEntity(e);
    self.mem.persistent.free(batch);
}

fn clearAllOverlayBatches(self: *Engine) void {
    for (self.overlay_batches.items) |batch| self.mem.persistent.free(batch);
    self.overlay_batches.clearRetainingCapacity();
}
