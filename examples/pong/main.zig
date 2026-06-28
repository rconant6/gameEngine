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

const bound_x: f32 = 13.5;
const max_ball_speed: f32 = 18.0;
const ball_speed_inc: f32 = 0.5;
const win_score: i64 = 7;

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
        .serve     = SD{ .scene = "pong", .world_policy = .preserve },
        .playing   = SD{ .world_policy = .preserve },
        .scored    = SD{ .world_policy = .preserve },
        .game_over = SD{ .scene = "game_over", .world_policy = .clear },
    });

    // Engine instantiates the bound "pong" scene when this transition resolves on
    // the next beginFrame; the ball reset then happens via stateEntered(.serve).
    try game.transitionTo(State, .serve);

    while (!game.shouldClose()) {
        game.beginFrame();
        game.clear(Colors.BLACK);

        if (game.isPressed(KeyCode.Esc)) break;

        // Bound scene just (re)instantiated for .serve — reset the ball to center.
        if (game.stateEntered(State, .serve)) serveBall(game);

        // (paddle bounds are now handled by the solid top/bottom walls — F2)

        switch (game.state(State).?) {
            .serve => {
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
                    try game.transitionTo(State, .serve);
                }
            },
            // .clear + .scene = "game_over" descriptor rebuilds the world on entry;
            // "press space to restart" is handled by an OnInput restart_game action
            // in the game_over scene (falls back to the manual check below for now).
            .game_over => {
                if (game.isPressed(KeyCode.Space)) {
                    game.restartGame(State, .serve);
                }
            },
        }

        game.tick();
        game.endFrame();
    }
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
