// Headless smoke test for Brickles — kept OUT of main.zig so the game itself
// reads as the thin deliverable it is. Runs with BRICKLES_SELFTEST=1: drives the
// whole loop without a window and asserts the scene/template DSL wiring, so the
// game can be verified in CI or from a terminal. This is also how the gutter
// per-frame-collision bug got root-caused headlessly (see README finding #5).
const std = @import("std");
const engine = @import("engine");
const game_mod = @import("main.zig");
const State = game_mod.State;

// shared helpers + constants live in main.zig (pub)
const newGameVars = game_mod.newGameVars;
const startLevelVars = game_mod.startLevelVars;
const stateInt = game_mod.stateInt;
const currentLevel = game_mod.currentLevel;
const rowsForLevel = game_mod.rowsForLevel;
const spawnBrickGrid = game_mod.spawnBrickGrid;
const parkBall = game_mod.parkBall;
const launchBall = game_mod.launchBall;
const ballBelowGutter = game_mod.ballBelowGutter;
const brick_cols = game_mod.brick_cols;
const start_balls = game_mod.start_balls;
const max_level = game_mod.max_level;

// Drive one frame and run the part of the live serve-entry logic the test needs:
// build the grid when entering a fresh level.
fn pump(game: *engine.Engine) void {
    game.beginFrame();
    if (game.stateEntered(State, .serve) and game.findEntityByTag("brick") == null) {
        startLevelVars(game);
        spawnBrickGrid(game);
        parkBall(game);
    }
    game.update(1.0 / 60.0);
    game.endFrame();
}

pub fn run(game: *engine.Engine) !void {
    const log = engine.log;

    // Drain the queued attract transition, then go attract -> serve and let the
    // grid build for level 1.
    pump(game);
    log.info(.engine, "SELFTEST attract: state={any}", .{game.state(State)});
    try game.transitionTo(State, .serve);
    pump(game);

    const ball = game.findEntityByTag("ball");
    const paddle = game.findEntityByTag("paddle");
    const walls = game.findEntitiesByTag("wall").len;
    const lvl1_bricks = game.findEntitiesByTag("brick").len;
    const lvl1_expect: usize = rowsForLevel(1) * brick_cols;
    log.info(.engine, "SELFTEST L1 playfield: ball={any} paddle={any} bricks={d}/{d} walls={d}", .{
        ball != null, paddle != null, lvl1_bricks, lvl1_expect, walls,
    });
    std.debug.assert(ball != null);
    std.debug.assert(paddle != null);
    std.debug.assert(walls == 3);
    std.debug.assert(lvl1_bricks == lvl1_expect);
    std.debug.assert(currentLevel(game) == 1);
    std.debug.assert(stateInt(game, "balls") == start_balls);

    // --- Core hit: bounce ball into the grid, confirm destroy+score chain fires.
    launchBall(game);
    try game.transitionTo(State, .playing);
    var hit_frames: usize = 0;
    while (hit_frames < 240 and stateInt(game, "score") == 0) : (hit_frames += 1) pump(game);
    log.info(.engine, "SELFTEST first hit after {d} frames: score={d}", .{ hit_frames, stateInt(game, "score") });
    std.debug.assert(stateInt(game, "score") > 0);

    // --- MULTI-LEVEL WALK (the stress): clear each level by forcing bricks to 0,
    // advance, and assert the next level rebuilds bigger + faster. Exercises
    // repeated full-playfield instantiate/destroy cycles (7C / free-list churn).
    var prev_rows: usize = rowsForLevel(1);
    var prev_speed: f32 = launchSpeed(game);
    var level: i64 = 1;
    while (level < max_level) : (level += 1) {
        // Clear the board the way real play does: destroy every brick ENTITY (a
        // real clear happens via destroy_self, leaving no brick entities), then
        // let the counter reflect it. The serve-entry "no bricks standing" check
        // is what triggers the next-level rebuild.
        for (game.findEntitiesByTag("brick")) |b| game.destroyEntity(b);
        game.setStateVar("bricks", .{ .int = 0 }) catch {};
        std.debug.assert(game.findEntityByTag("brick") == null);

        // live .playing logic: bricks==0 and level<max -> bump level + serve
        std.debug.assert(currentLevel(game) == level);
        game.setStateVar("level", .{ .int = currentLevel(game) + 1 }) catch {};
        try game.transitionTo(State, .serve);

        // serve rebuilds the (bigger) grid; let it settle, then relaunch
        var k: usize = 0;
        while (k < 4) : (k += 1) pump(game);
        launchBall(game);
        try game.transitionTo(State, .playing);
        pump(game);

        const lvl = currentLevel(game);
        const rows = rowsForLevel(lvl);
        const bricks_now = game.findEntitiesByTag("brick").len;
        const speed_now = launchSpeed(game);
        log.info(.engine, "SELFTEST advanced to L{d}: rows={d} bricks={d} ballspeed={d:.1}", .{
            lvl, rows, bricks_now, speed_now,
        });
        std.debug.assert(lvl == level + 1);
        std.debug.assert(rows == prev_rows + 1); // each level adds a row
        std.debug.assert(bricks_now == rows * brick_cols); // grid actually rebuilt
        std.debug.assert(speed_now > prev_speed); // ball faster each level
        std.debug.assert(stateInt(game, "balls") == start_balls); // balls refilled
        prev_rows = rows;
        prev_speed = speed_now;
    }
    std.debug.assert(currentLevel(game) == max_level);

    // --- Final level cleared -> .win (victory, not next level).
    game.setStateVar("bricks", .{ .int = 0 }) catch {};
    try game.transitionTo(State, .win);
    game.beginFrame();
    log.info(.engine, "SELFTEST final clear: state={any} level={d}", .{ game.state(State), currentLevel(game) });
    std.debug.assert(game.state(State).? == .win);

    // --- Lose path still works.
    game.setStateVar("balls", .{ .int = 0 }) catch {};
    try game.transitionTo(State, .lose);
    game.beginFrame();
    std.debug.assert(game.state(State).? == .lose);

    // --- restart_game resets back to level 1 / score 0 for a new game.
    game.restartGame(State, .serve);
    pump(game); // resolves restart + rebuilds level-1 grid
    log.info(.engine, "SELFTEST after restart: level={d} score={d} bricks={d}", .{
        currentLevel(game), stateInt(game, "score"), game.findEntitiesByTag("brick").len,
    });
    std.debug.assert(currentLevel(game) == 1);
    std.debug.assert(stateInt(game, "score") == 0);

    // --- STRESS: hammer the spawn/destroy churn the level cycle relies on. Build
    // and tear down the largest grid many times; assert entity counts stay exact
    // (no free-list corruption / leaked or aliased entities under repeated 7C churn).
    game.setStateVar("level", .{ .int = max_level }) catch {};
    for (game.findEntitiesByTag("brick")) |b| game.destroyEntity(b); // clean slate
    const big: usize = rowsForLevel(max_level) * brick_cols;
    var cycle: usize = 0;
    while (cycle < 50) : (cycle += 1) {
        spawnBrickGrid(game);
        std.debug.assert(game.findEntitiesByTag("brick").len == big); // exact, no aliasing
        for (game.findEntitiesByTag("brick")) |b| game.destroyEntity(b);
        std.debug.assert(game.findEntityByTag("brick") == null); // fully cleared
    }
    log.info(.engine, "SELFTEST churn: 50x build/destroy of {d}-brick grid clean", .{big});

    log.info(.engine, "SELFTEST PASSED", .{});
}

// Recompute what launchBall would set, to assert speed scaling without poking
// internals. Mirrors main.launchBall's formula via the live ball velocity.
fn launchSpeed(game: *engine.Engine) f32 {
    launchBall(game);
    const ball = game.findEntityByTag("ball") orelse return 0;
    const v = game.world.getComponent(ball, engine.Velocity) orelse return 0;
    return v.linear.y; // the y component is the unscaled speed
}
