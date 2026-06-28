const std = @import("std");
const engine = @import("engine");
const KeyCode = engine.KeyCode;
const Colors = engine.Colors;
const Velocity = engine.Velocity;
const Transform = engine.Transform;
const V2 = engine.V2;

const logical_width = 1920;
const logical_height = 1080;

pub const State = enum { attract, serve, playing, win, lose };
const SD = engine.StateDescriptor;

pub const start_balls: i64 = 3;
pub const max_level: i64 = 5;

const base_ball_speed: f32 = 11.0;
const ball_speed_per_level: f32 = 2.0; // each level launches faster

// Brick grid layout. Placement lives here (the scene DSL can't instantiate a
// template at N positions yet — finding #1); the brick's look + behavior all
// live in bricks.template. Levels add rows + denser palette as difficulty rises.
pub const brick_cols = 9;
const base_brick_rows = 3; // level 1; +1 row per level
const brick_w: f32 = 3.0; // template half_width 1.4 -> ~2.8 + gap
const brick_h: f32 = 1.3;
const grid_top: f32 = 7.5;

// Per-level color palettes (top row -> bottom). Index by level-1, clamped.
// Each level themes its rows differently, churning several distinct templates.
const level_palettes = [_][]const []const u8{
    &.{ "BrickGreen", "Brick", "Brick" }, // L1: easy
    &.{ "BrickGold", "BrickGreen", "Brick", "Brick" }, // L2
    &.{ "BrickOrange", "BrickGold", "BrickGreen", "Brick", "Brick" }, // L3
    &.{ "BrickRed", "BrickOrange", "BrickGold", "BrickGreen", "Brick", "Brick" }, // L4
    &.{ "BrickPurple", "BrickRed", "BrickOrange", "BrickGold", "BrickGreen", "Brick", "Brick" }, // L5
};

pub fn rowsForLevel(level: i64) usize {
    return @intCast(base_brick_rows + (level - 1)); // L1=3 ... L5=7
}

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;
    const env = init.environ_map;

    var app = try engine.App.init(gpa, io, env, .{
        .title = "Brickles",
        .width = logical_width,
        .height = logical_height,
    });
    defer app.deinit();

    const game = engine.Engine.init(&app);
    defer game.deinit();

    // NOTE: trailing slash is required — loadTemplates concatenates dir+filename
    // with no separator, so "assets/templates" (no slash) yields FileNotFound.
    try game.loadTemplates("assets/templates/");
    try game.loadScene("attract", "attract");
    try game.loadScene("brickles", "brickles");
    try game.loadScene("win", "win");
    try game.loadScene("lose", "lose");

    try game.declareStates(State, .{
        .attract = SD{ .scene = "attract", .world_policy = .clear },
        .serve   = SD{ .scene = "brickles", .world_policy = .preserve },
        .playing = SD{ .world_policy = .preserve },
        .win     = SD{ .scene = "win", .world_policy = .clear },
        .lose    = SD{ .scene = "lose", .world_policy = .clear },
    });

    newGameVars(game);
    try game.transitionTo(State, .attract);

    // Headless smoke test (BRICKLES_SELFTEST=1) lives in selftest.zig so the game
    // below stays the thin deliverable. It drives the whole loop without a window.
    if (env.get("BRICKLES_SELFTEST") != null) {
        try @import("selftest.zig").run(game);
        return;
    }

    while (!game.shouldClose()) {
        game.beginFrame();
        game.clear(Colors.BLACK);

        if (game.isPressed(KeyCode.Esc)) break;

        // Entering serve: the brickles scene (re)instantiated. No bricks standing
        // => start of a level (fresh game OR next level after a win): refill
        // balls/brick-count for the current level and build its grid. Bricks still
        // standing => a re-serve after losing a ball: leave the field alone.
        // (Keyed off entities, not the counter var — finding #3.)
        if (game.stateEntered(State, .serve)) {
            // The gutter decrements balls + re-serves on a ball-loss (pure scene
            // data now). If that emptied the last ball, the re-serve lands here
            // with balls<=0 -> game over. (Checked at entry, not in .playing, so
            // it never races the gutter's transition in the same frame.)
            if (stateInt(game, "balls") <= 0) {
                try game.transitionTo(State, .lose);
            } else if (game.findEntityByTag("brick") == null) {
                startLevelVars(game);
                spawnBrickGrid(game);
                parkBall(game);
            } else {
                parkBall(game);
            }
        }

        switch (game.state(State) orelse .attract) {
            .attract => {
                if (game.isPressed(KeyCode.Space)) try game.transitionTo(State, .serve);
            },
            .serve => {
                if (game.isPressed(KeyCode.Space)) {
                    launchBall(game);
                    try game.transitionTo(State, .playing);
                }
            },
            .playing => {
                // Ball-loss (balls-- + re-serve) is now pure scene data: the
                // gutter's OnCollision (phase "enter") fires it once per crossing.
                // main.zig only owns the level-clear check here, and the lose
                // threshold at serve-entry above (the gutter can't read balls<=0).
                if (stateInt(game, "bricks") <= 0) {
                    // Level cleared. More levels left -> advance + serve the next
                    // (harder) one; bricks gone means serve rebuilds the grid.
                    // Final level cleared -> the victory screen.
                    if (currentLevel(game) < max_level) {
                        game.setStateVar("level", .{ .int = currentLevel(game) + 1 }) catch {};
                        try game.transitionTo(State, .serve);
                    } else {
                        try game.transitionTo(State, .win);
                    }
                }
            },
            .win, .lose => {
                if (game.isPressed(KeyCode.Space)) game.restartGame(State, .serve);
            },
        }

        game.tick();
        game.endFrame();
    }
}

// MARK: helpers (pub so selftest.zig can reuse them)

// Full reset — new game from level 1. (level survives a win->next-level serve but
// is wiped here, so a fresh game always starts at 1.)
pub fn newGameVars(game: *engine.Engine) void {
    game.setStateVar("score", .{ .int = 0 }) catch {};
    game.setStateVar("level", .{ .int = 1 }) catch {};
    startLevelVars(game);
}

// Per-level reset — keep score + level, refill balls + recompute brick count for
// the current level's grid.
pub fn startLevelVars(game: *engine.Engine) void {
    const level = currentLevel(game);
    game.setStateVar("balls", .{ .int = start_balls }) catch {};
    game.setStateVar("bricks", .{ .int = @as(i64, @intCast(rowsForLevel(level))) * brick_cols }) catch {};
}

pub fn currentLevel(game: *engine.Engine) i64 {
    const l = stateInt(game, "level");
    return if (l < 1) 1 else l;
}

pub fn stateInt(game: *engine.Engine, key: []const u8) i64 {
    return (game.getStateVar(key) orelse engine.StateValue{ .int = 0 }).int;
}

pub fn spawnBrickGrid(game: *engine.Engine) void {
    const level = currentLevel(game);
    const rows = rowsForLevel(level);
    const palette = level_palettes[@intCast(@min(level, max_level) - 1)];
    const total_w: f32 = @as(f32, brick_cols - 1) * brick_w;
    const x0: f32 = -total_w / 2.0;
    var r: usize = 0;
    while (r < rows) : (r += 1) {
        // pick this row's template from the palette (clamped if rows > palette len)
        const tmpl = palette[@min(r, palette.len - 1)];
        var c: usize = 0;
        while (c < brick_cols) : (c += 1) {
            const x = x0 + @as(f32, @floatFromInt(c)) * brick_w;
            const y = grid_top - @as(f32, @floatFromInt(r)) * brick_h;
            _ = game.world.createEntityFromTemplate(tmpl, V2{ .x = x, .y = y }) catch {};
        }
    }
}

pub fn parkBall(game: *engine.Engine) void {
    const ball = game.findEntityByTag("ball") orelse return;
    const paddle = game.findEntityByTag("paddle");
    const px: f32 = if (paddle) |p|
        (game.world.getComponent(p, Transform) orelse return).position.x
    else
        0.0;
    if (game.world.getComponentMut(ball, Transform)) |t| {
        t.position = .{ .x = px, .y = -7.6 };
    }
    if (game.world.getComponentMut(ball, Velocity)) |v| {
        v.linear = .{ .x = 0, .y = 0 };
    }
}

pub fn launchBall(game: *engine.Engine) void {
    const ball = game.findEntityByTag("ball") orelse return;
    const level = currentLevel(game);
    const speed = base_ball_speed + @as(f32, @floatFromInt(level - 1)) * ball_speed_per_level;
    if (game.world.getComponentMut(ball, Velocity)) |v| {
        v.linear = .{ .x = speed * 0.4, .y = speed };
    }
}

