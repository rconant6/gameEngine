const std = @import("std");
const engine = @import("engine");
const KeyCode = engine.KeyCode;
const log = engine.log;
const Colors = engine.Colors;
const Velocity = engine.Velocity;

const logical_width = 1920;
const logical_height = 1080;

const State = enum { serve, playing, scored, game_over };
const SD = engine.StateDescriptor;

const bound_y: f32 = 9.6;
const bound_x: f32 = 13.5;
const max_ball_speed: f32 = 18.0;
const ball_speed_inc: f32 = 0.5;
const win_score: i64 = 7;

fn monoMillis() i64 {
    var ts: std.c.timespec = undefined;
    _ = std.c.clock_gettime(std.c.CLOCK.MONOTONIC, &ts);
    return ts.sec * 1000 + @divTrunc(ts.nsec, 1_000_000);
}

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;
    const env = init.environ_map;

    var app = try engine.App.init(gpa, io, env, .{
        .title = "Pong",
        .width = logical_width,
        .height = logical_height,
    });
    defer app.deinit();

    const game = engine.Engine.init(&app);
    defer game.deinit();

    try game.loadScene("pong", "pong");
    try game.loadScene("game_over", "game_over");

    try game.declareStates(State, .{
        .serve     = SD{ .world_policy = .preserve },
        .playing   = SD{ .world_policy = .preserve },
        .scored    = SD{ .world_policy = .preserve },
        .game_over = SD{ .world_policy = .clear },
    });

    try game.transitionTo(State, .serve);
    try game.setActiveScene("pong");
    try game.instantiateActiveScene();
    game.setStateVar("score_left",   .{ .int = 0 })   catch {};
    game.setStateVar("score_right",  .{ .int = 0 })   catch {};
    game.setStateVar("pong_loaded",  .{ .bool = true }) catch {};
    serveBall(game);

    var prev_ms: i64 = monoMillis();

    while (!game.shouldClose()) {
        const now_ms = monoMillis();
        const dt: f32 = @as(f32, @floatFromInt(now_ms - prev_ms)) / 1000.0;
        prev_ms = now_ms;

        game.beginFrame();
        game.clear(Colors.BLACK);

        if (game.isPressed(KeyCode.Esc)) break;

        clampPaddleVelocity(game, "paddle_left");
        clampPaddleVelocity(game, "paddle_right");

        switch (game.state(State).?) {
            .serve => {
                if (game.getStateVar("pong_loaded") == null) {
                    try game.setActiveScene("pong");
                    try game.instantiateActiveScene();
                    game.setStateVar("pong_loaded",  .{ .bool = true }) catch {};
                    game.setStateVar("score_left",   .{ .int = 0 })    catch {};
                    game.setStateVar("score_right",  .{ .int = 0 })    catch {};
                    serveBall(game);
                }
                if (game.isPressed(KeyCode.Space)) {
                    launchBall(game, 1.0);
                    try game.transitionTo(State, .playing);
                }
            },
            .playing => {
                checkScore(game);
            },
            .scored => {
                const sl = (game.getStateVar("score_left")  orelse engine.StateValue{ .int = 0 }).int;
                const sr = (game.getStateVar("score_right") orelse engine.StateValue{ .int = 0 }).int;
                if (sl >= win_score or sr >= win_score) {
                    try game.transitionTo(State, .game_over);
                } else {
                    serveBall(game);
                    try game.transitionTo(State, .serve);
                }
            },
            .game_over => {
                if (game.getStateVar("game_over_loaded") == null) {
                    try game.setActiveScene("game_over");
                    try game.instantiateActiveScene();
                    game.setStateVar("game_over_loaded", .{ .bool = true }) catch {};
                }
                if (game.isPressed(KeyCode.Space)) {
                    game.restartGame(State, .serve);
                }
            },
        }

        game.update(dt);
        game.endFrame();
    }
}

fn clampPaddleVelocity(game: *engine.Engine, tag: []const u8) void {
    const entity = game.findEntityByTag(tag) orelse return;
    const vel = game.world.getComponentMut(entity, Velocity) orelse return;
    const transform = game.world.getComponent(entity, engine.Transform) orelse return;

    const half_h: f32 = 1.5;
    if (transform.position.y + half_h >= bound_y and vel.linear.y > 0) vel.linear.y = 0;
    if (transform.position.y - half_h <= -bound_y and vel.linear.y < 0) vel.linear.y = 0;
}

fn checkScore(game: *engine.Engine) void {
    const entity = game.findEntityByTag("ball") orelse return;
    const transform = game.world.getComponent(entity, engine.Transform) orelse return;
    const pos = transform.position;

    if (pos.x < -bound_x) {
        const sr = (game.getStateVar("score_right") orelse engine.StateValue{ .int = 0 }).int;
        game.setStateVar("score_right", .{ .int = sr + 1 }) catch {};
        game.transitionTo(State, .scored) catch {};
    } else if (pos.x > bound_x) {
        const sl = (game.getStateVar("score_left") orelse engine.StateValue{ .int = 0 }).int;
        game.setStateVar("score_left", .{ .int = sl + 1 }) catch {};
        game.transitionTo(State, .scored) catch {};
    }
}

fn serveBall(game: *engine.Engine) void {
    const entity = game.findEntityByTag("ball") orelse return;
    const vel = game.world.getComponentMut(entity, Velocity) orelse return;
    const transform = game.world.getComponentMut(entity, engine.Transform) orelse return;
    vel.linear.x = 0;
    vel.linear.y = 0;
    transform.position.x = 0;
    transform.position.y = 0;
}

fn launchBall(game: *engine.Engine, x_dir: f32) void {
    const entity = game.findEntityByTag("ball") orelse return;
    const vel = game.world.getComponentMut(entity, Velocity) orelse return;
    vel.linear.x = 7.0 * x_dir;
    vel.linear.y = 5.0;
}
