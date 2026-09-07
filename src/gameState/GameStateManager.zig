const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const GameMemory = @import("memory");
const log = @import("debug").log;

pub const WorldPolicy = enum {
    preserve,
    clear,
};

pub const TransitionKind = enum {
    transition,
    push,
    pop,
    advance,
    retreat,
    descend,
    ascend,
    restart,
    restart_game,
};

// Allows control of what gets updated in simulations
// use case is for the level editor vs. an actual game (want camera but nothing else)
pub const SimulateOpts = struct {
    movement: bool = true,
    physics: bool = true,
    collision: bool = true,
    solid: bool = true,
    actions: bool = true,
    camera: bool = true,
    lifetime: bool = true,
    state_text: bool = true,
};

pub const StateDescriptor = struct {
    scene: ?[]const u8 = null,
    world_policy: WorldPolicy = .preserve,
    systems: SimulateOpts = .{},
    user_data: ?*anyopaque = null,
};

pub const StateValue = union(enum) {
    int: i64,
    float: f64,
    bool: bool,
    string: []const u8,
};

pub const StateAction = union(enum) {
    transition_to: []const u8,
    push: *GameState, // overlay, always preserves, suspends current
    transition_to_node: *GameState, // go direct to state
    restart_game_node: *GameState, // go direct to state w/ clean up
    pop: void, // return from overlay
    advance: void, // next sibling
    goback: void, // prev sibling
    descend: void, // first child
    ascend: void, // parent
    restart_state: void, // re-enter current
    restart_game: []const u8, // full reset, goes to named state
};

pub const TransitionResult = struct {
    prev_state: ?[]const u8,
    next_state: []const u8,
    world_policy: WorldPolicy,
    systems: SimulateOpts,
    kind: TransitionKind,
    scene: ?[]const u8,
};

pub const GameState = struct {
    name: []const u8,

    world_policy: WorldPolicy = .preserve,
    systems: SimulateOpts = .{},
    user_data: ?*anyopaque = null, // place for game maker to pass data

    scene: ?[]const u8 = null,
    parent: ?*GameState = null,
    first_child: ?*GameState = null,
    next_sibling: ?*GameState = null,
    prev_sibling: ?*GameState = null,
};

const MAX_STACK_DEPTH = 16;

pub const GameStateManager = struct {
    mem: *GameMemory,
    roots: ArrayList(*GameState),
    current: ?*GameState,
    pending: ?StateAction,
    stack: [MAX_STACK_DEPTH]*GameState,
    stack_depth: usize,
    game_values: StringHashMap(StateValue),

    pub fn init(mem: *GameMemory) GameStateManager {
        return GameStateManager{
            .mem = mem,
            .roots = .empty,
            .stack = undefined,
            .stack_depth = 0,
            .current = null,
            .pending = null,
            .game_values = .init(mem.persistent),
        };
    }
    pub fn deinit(self: *GameStateManager) void {
        self.clearVars();
        self.game_values.deinit();
        for (self.roots.items) |root| {
            freeSubtree(self.mem.persistent, root);
        }
        self.roots.deinit(self.mem.persistent);
    }

    pub fn declareRoot(
        self: *GameStateManager,
        name: []const u8,
        desc: StateDescriptor,
    ) !*GameState {
        const node = self.mem.persistent.create(GameState) catch |e| {
            log.err(
                .engine,
                "Unable to create gameState: {s} {any}",
                .{ name, e },
            );
            return e;
        };
        node.* = .{
            .name = try self.mem.persistent.dupe(u8, name),
            .world_policy = desc.world_policy,
            .systems = desc.systems,
            .user_data = desc.user_data,
            .scene = if (desc.scene) |s| try self.mem.persistent.dupe(u8, s) else null,
            .parent = null,
            .first_child = null,
            .next_sibling = null,
            .prev_sibling = null,
        };

        if (self.roots.items.len > 0) {
            const prev_idx: usize = self.roots.items.len - 1;
            const prev = self.roots.items[prev_idx];
            prev.next_sibling = node;
            node.prev_sibling = prev;
        }

        try self.roots.append(self.mem.persistent, node);

        return node;
    }
    pub fn declareChild(
        self: *GameStateManager,
        name: []const u8,
        parent: *GameState,
        d: StateDescriptor,
    ) !*GameState {
        const node = self.mem.persistent.create(GameState) catch |e| {
            log.err(
                .engine,
                "Unable to create gameState: {s} {any}",
                .{ name, e },
            );
            return e;
        };
        node.* = .{
            .name = try self.mem.persistent.dupe(u8, name),
            .world_policy = d.world_policy,
            .systems = d.systems,
            .user_data = d.user_data,
            .scene = if (d.scene) |s| try self.mem.persistent.dupe(u8, s) else null,
            .parent = parent,
            .first_child = null,
            .next_sibling = null,
            .prev_sibling = null,
        };

        if (parent.first_child == null) {
            parent.first_child = node;
            return node;
        }

        var last_child = parent.first_child.?;
        while (last_child.next_sibling != null) : (last_child = last_child.next_sibling.?) {}
        last_child.next_sibling = node;
        node.prev_sibling = last_child;

        std.debug.assert(last_child.parent == node.parent);

        return node;
    }

    // transition queue — engine reads in beginFrame
    pub fn queueAction(self: *GameStateManager, action: StateAction) void {
        if (self.pending != null) {
            log.warn(
                .engine,
                "State action dropped, '{s}' pending",
                .{@tagName(self.pending.?)},
            );
            return; // first wins
        }
        self.pending = action;
    }
    pub fn resolvePending(
        self: *GameStateManager,
    ) ?TransitionResult {
        const action = self.pending orelse return null;
        self.pending = null;

        switch (action) {
            .transition_to => |name| {
                const gs = findByName(self, name) orelse {
                    log.err(
                        .engine,
                        "GameStateManager: unknown state '{s}'",
                        .{name},
                    );
                    return null;
                };
                return self.applyTransition(gs);
            },
            .transition_to_node => |n| return self.applyTransition(n),
            .push => |name| return self.applyPush(name),
            .pop => return self.applyPop(),
            .advance => return self.applyAdvance(),
            .goback => return self.applyRetreat(),
            .descend => return self.applyDescend(),
            .ascend => return self.applyAscend(),
            .restart_state => return self.applyRestartState(),
            .restart_game => |name| {
                const gs = findByName(self, name) orelse {
                    log.err(
                        .engine,
                        "GameStateManager: unknown state '{s}'",
                        .{name},
                    );
                    return null;
                };
                return self.applyRestartGame(gs);
            },
            .restart_game_node => |n| return self.applyRestartGame(n),
        }
    }

    // MARK: game states data
    pub fn setStateVar(self: *GameStateManager, key: []const u8, val: StateValue) !void {
        var owned = val;
        if (val == .string) owned = .{ .string = try self.mem.persistent.dupe(
            u8,
            val.string,
        ) };
        errdefer if (owned == .string) self.mem.persistent.free(owned.string);

        if (self.game_values.getPtr(key)) |existing| {
            if (existing.* == .string) self.mem.persistent.free(existing.string);
            existing.* = owned;
            return;
        }
        const owned_key = try self.mem.persistent.dupe(u8, key);
        errdefer self.mem.persistent.free(owned_key);
        try self.game_values.put(owned_key, owned);
    }

    pub fn getStateVar(self: *GameStateManager, key: []const u8) ?StateValue {
        return self.game_values.get(key);
    }

    pub fn clearVars(self: *GameStateManager) void { // called by restart_game
        var iter = self.game_values.iterator();
        while (iter.next()) |val| {
            const value = val.value_ptr.*;
            switch (value) {
                .string => |s| self.mem.persistent.free(s),
                else => {},
            }
            self.mem.persistent.free(val.key_ptr.*);
        }
        self.game_values.clearRetainingCapacity();
    }

    // MARK: internal navigation
    // Pure transition: set current to an already-resolved node, no reset.
    // Both .transition_to (name → findByName → here) and .transition_to_node
    // (already a node) converge here.
    fn applyTransition(
        self: *GameStateManager,
        gs: *GameState,
    ) ?TransitionResult {
        const prev = self.current;
        self.current = gs;

        return .{
            .prev_state = if (prev) |p| p.name else null,
            .next_state = gs.name,

            .world_policy = gs.world_policy,
            .systems = gs.systems,

            .scene = gs.scene,
            .kind = .transition,
        };
    }

    fn applyAdvance(self: *GameStateManager) ?TransitionResult {
        const prev = self.current orelse return null;
        const new = prev.next_sibling orelse return null;

        self.current = new;

        return .{
            .next_state = new.name,
            .prev_state = prev.name,

            .world_policy = new.world_policy,
            .systems = new.systems,

            .scene = new.scene,
            .kind = .advance,
        };
    }
    fn applyRetreat(self: *GameStateManager) ?TransitionResult {
        const prev = self.current orelse return null;
        const next = prev.prev_sibling orelse return null;

        self.current = next;

        return .{
            .next_state = next.name,
            .prev_state = prev.name,

            .world_policy = next.world_policy,
            .systems = next.systems,

            .scene = next.scene,
            .kind = .retreat,
        };
    }

    fn applyDescend(self: *GameStateManager) ?TransitionResult {
        const prev = self.current orelse return null;
        const next = prev.first_child orelse return null;

        self.current = next;

        return .{
            .next_state = next.name,
            .prev_state = prev.name,

            .world_policy = next.world_policy,
            .systems = next.systems,

            .scene = next.scene,
            .kind = .descend,
        };
    }
    fn applyAscend(self: *GameStateManager) ?TransitionResult {
        const prev = self.current orelse return null;
        const next = prev.parent orelse return null;

        self.current = next;

        return .{
            .next_state = next.name,
            .prev_state = prev.name,

            .world_policy = next.world_policy,
            .systems = next.systems,

            .scene = next.scene,
            .kind = .ascend,
        };
    }

    fn applyPush(self: *GameStateManager, node: *GameState) ?TransitionResult {
        if (self.stack_depth >= MAX_STACK_DEPTH) {
            log.err(
                .engine,
                "GameStateManager: stack overflow (max: {d})",
                .{MAX_STACK_DEPTH},
            );
            return null;
        }
        if (self.current) |c| {
            self.stack[self.stack_depth] = c;
            self.stack_depth += 1;
        }
        const prev = self.current;
        self.current = node;
        return .{
            .prev_state = if (prev) |p| p.name else null,
            .next_state = node.name,

            .world_policy = .preserve,
            .systems = node.systems,

            .scene = node.scene,
            .kind = .push,
        };
    }
    fn applyPop(self: *GameStateManager) ?TransitionResult {
        if (self.stack_depth == 0) {
            log.err(.engine, "GameStateManager: stack underflow", .{});
            return null;
        }
        self.stack_depth -= 1;
        const node = self.stack[self.stack_depth];
        const prev = self.current;
        self.current = node;
        return .{
            .prev_state = if (prev) |p| p.name else null,
            .next_state = node.name,

            .world_policy = .preserve,
            .systems = node.systems,

            .scene = node.scene,
            .kind = .pop,
        };
    }
    fn applyRestartState(self: *GameStateManager) ?TransitionResult {
        const cur = self.current orelse return null;
        return .{
            .next_state = cur.name,
            .prev_state = cur.name,

            .world_policy = cur.world_policy,
            .systems = cur.systems,

            .scene = cur.scene,
            .kind = .restart,
        };
    }

    fn applyRestartGame(self: *GameStateManager, gs: *GameState) ?TransitionResult {
        self.stack_depth = 0;
        self.clearVars();
        self.mem.resetGame();
        self.game_values.clearRetainingCapacity();
        var result = self.applyTransition(gs) orelse return null;
        result.world_policy = .clear;
        result.kind = .restart_game;
        return result;
    }

    // MARK: helpers
    pub fn findByName(self: *GameStateManager, name: []const u8) ?*GameState {
        for (self.roots.items) |root| {
            if (findInSubtree(root, name)) |node| return node;
        }
        return null;
    }
    fn findInSubtree(node: *GameState, name: []const u8) ?*GameState {
        if (std.mem.eql(u8, node.name, name)) return node;
        var child = node.first_child;
        while (child) |c| : (child = c.next_sibling) {
            if (findInSubtree(c, name)) |found| return found;
        }
        return null;
    }
    fn freeSubtree(persistent: Allocator, node: *GameState) void {
        var child = node.first_child;
        while (child) |c| {
            const next = c.next_sibling;
            freeSubtree(persistent, c);
            child = next;
        }
        persistent.free(node.name);
        if (node.scene) |s| {
            persistent.free(s);
        }
        persistent.destroy(node);
    }
};
