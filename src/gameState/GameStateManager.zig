const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const SimulateOpts = @import("systems").SimulateOpts;
const GameMemory = @import("math").GameMemory;
const log = @import("debug").log;

pub const WorldPolicy = enum {
    preserve,
    clear,
};

pub const StateDescriptor = struct {
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
};

pub const GameState = struct {
    name: []const u8,

    world_policy: WorldPolicy = .preserve,
    systems: SimulateOpts = .{},
    user_data: ?*anyopaque = null, // place for game maker to pass data

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
            .game_values = .init(mem.game),
        };
    }
    pub fn deinit(self: *GameStateManager) void {
        for (self.roots.items) |root| {
            freeSubtree(self.mem.persistent, root);
        }
        self.roots.deinit(self.mem.persistent);

        var iter = self.game_values.iterator();
        while (iter.next()) |val| {
            const value = val.value_ptr.*;
            switch (value) {
                .string => |s| self.mem.game.free(s),
                else => {},
            }
            self.mem.game.free(val.key_ptr.*);
        }
    }

    pub fn declareRoot(
        self: *GameStateManager,
        name: []const u8,
        d: StateDescriptor,
    ) !*GameState {
        const node = self.mem.persistent.create(GameState) catch |e| {
            log.err(.engine, "Unable to create gameState: {s} {any}", .{ name, e });
            return e;
        };
        node.* = .{
            .name         = try self.mem.persistent.dupe(u8, name),
            .world_policy = d.world_policy,
            .systems      = d.systems,
            .user_data    = d.user_data,
            .parent       = null,
            .first_child  = null,
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
            log.err(.engine, "Unable to create gameState: {s} {any}", .{ name, e });
            return e;
        };
        node.* = .{
            .name         = try self.mem.persistent.dupe(u8, name),
            .world_policy = d.world_policy,
            .systems      = d.systems,
            .user_data    = d.user_data,
            .parent       = parent,
            .first_child  = null,
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
        if (self.pending != null) return; // first wins
        self.pending = action;
    }
    pub fn resolvePending(
        self: *GameStateManager,
    ) ?TransitionResult {
        const action = self.pending orelse return null;
        self.pending = null;

        switch (action) {
            .transition_to => |name| return self.applyTransition(name),
            .push => |name| return self.applyPush(name),
            .pop => return self.applyPop(),
            .advance => return self.applyAdvance(),
            .goback => return self.applyRetreat(),
            .restart_state => return self.applyRestart(),
            .restart_game => |name| {
                self.mem.resetGame();
                self.game_values = .init(self.mem.game);
                var result = self.applyTransition(name) orelse return null;
                result.world_policy = .clear;
                return result;
            },
            else => return null,
        }
    }

    // MARK: game states data
    pub fn setStateVar(
        self: *GameStateManager,
        key: []const u8,
        val: StateValue,
    ) !void {
        const gop = try self.game_values.getOrPut(key);
        if (gop.found_existing) {
            gop.value_ptr.* = val;
        } else {
            gop.key_ptr.* = try self.mem.game.dupe(u8, key);
            gop.value_ptr.* = val;
        }
    }
    pub fn getStateVar(self: *GameStateManager, key: []const u8) ?StateValue {
        return self.game_values.get(key);
    }
    pub fn clearVars(self: *GameStateManager) void { // called by restart_game

        var iter = self.game_values.iterator();
        while (iter.next()) |val| {
            const value = val.value_ptr.*;
            switch (value) {
                .string => |s| self.mem.game.free(s),
                else => {},
            }
            self.mem.game.free(val.key_ptr.*);
        }
        self.game_values.clearRetainingCapacity();
    }

    // MARK: internal navigation
    fn applyTransition(
        self: *GameStateManager,
        name: []const u8,
    ) ?TransitionResult {
        const gs = findByName(self, name) orelse {
            log.err(.engine, "GameStateManager: unknown state '{s}'", .{name});
            return null;
        };

        const prev = self.current;
        self.current = gs;

        return .{
            .prev_state = if (prev) |p| p.name else null,
            .next_state = gs.name,

            .world_policy = gs.world_policy,
            .systems = gs.systems,
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
        };
    }

    fn applyPush(self: *GameStateManager, node: *GameState) ?TransitionResult {
        if (self.stack_depth >= MAX_STACK_DEPTH) {
            log.err(.engine, "GameStateManager: stack overflow (max: {d})", .{MAX_STACK_DEPTH});
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
        };
    }
    fn applyRestart(self: *GameStateManager) ?TransitionResult {
        const prev = self.current orelse return null;

        return .{
            .next_state = prev.name,
            .prev_state = prev.name,

            .world_policy = prev.world_policy,
            .systems = prev.systems,
        };
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
    fn freeSubtree(allocator: Allocator, node: *GameState) void {
        var child = node.first_child;
        while (child) |c| {
            const next = c.next_sibling;
            freeSubtree(allocator, c);
            child = next;
        }
        allocator.free(node.name);
        allocator.destroy(node);
    }
};
