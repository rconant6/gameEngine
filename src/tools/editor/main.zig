// main
const std = @import("std");
const engine = @import("engine");
const App = @import("app").App;
const assets = @import("assets");
const Font = assets.Font;
const scene = @import("scene");
const scene_fmt = @import("scene-format");
const ui = @import("ui");
const UILayer = ui.UILayer;
const debug = @import("debug");
const log = debug.log;
const rend = @import("renderer");
const Colors = rend.Colors;
const Color = rend.Color;

const Hierarchy = @import("Hierarchy.zig");
const Inspector = @import("Inspector.zig");
const EditorState = @import("EditorState.zig");

const logical_width: i32 = 1920;
const logical_height: i32 = 1080;

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    var app = try App.init(gpa, io, .{
        .title = "Scene Editor",
        .width = logical_width,
        .height = logical_height,
    });
    defer app.deinit();

    const eng = engine.Engine.init(&app);
    defer eng.deinit();

    var state = EditorState.init(gpa);
    defer state.deinit();

    // Load test scene for development
    const test_scene_src = @embedFile("test_scene.scene");
    const test_scene_src_z = try std.mem.concatWithSentinel(gpa, u8, &.{test_scene_src}, 0);
    defer gpa.free(test_scene_src_z);
    const parsed = scene_fmt.parseString(gpa, test_scene_src_z, "game.scene") catch |err| blk: {
        log.err(.application, "Failed to parse test scene: {any}", .{err});
        break :blk null;
    };
    if (parsed) |sf| {
        const sf_ptr = try gpa.create(scene_fmt.SceneFile);
        sf_ptr.* = sf;
        state.scene_file = sf_ptr;
    }

    var ui_font = Font.initFromMemory(gpa, assets.embedded_default_font) catch |err| {
        log.err(.application, "Failed to load font: {any}", .{err});
        @panic("Cannot load font");
    };
    defer ui_font.deinit();

    const size = ui_font.measureText("Hello World", 24.0);
    log.info(.assets, "Font: width: {d}, height {d}", .{ size.x, size.y });

    var ui_layer = UILayer.init(gpa);
    defer ui_layer.deinit();

    ui_layer.addView(
        "hierarchy",
        .{ .x = 0, .y = 0, .width = 280, .height = 1080 },
        Hierarchy.buildTree,
        .{},
    );
    ui_layer.addView(
        "inspector",
        .{ .x = 1620, .y = 0, .width = 300, .height = 1080 },
        Inspector.buildTree,
        .{},
    );

    const ctx: rend.RenderContext = .{
        .camera_loc = .{ .x = 0, .y = 0 },
        .height = logical_height,
        .width = logical_width,
        .ortho_size = logical_height / 2,
    };

    while (app.isRunning()) {
        eng.beginFrame();

        eng.clear(Colors.DARK_GRAY);
        eng.update(0, .{});

        if (app.kb.isPressed(.Esc)) break;

        const mouse_pos = app.mouse.position;

        handleInput(&state, &app);
        drawViewport(&state, &app);
        ui_layer.update(
            &state,
            mouse_pos.x,
            mouse_pos.y,
            app.mouse.buttons.isPressed(.Left),
            app.mouse.buttons.isReleased(.Left),
        );
        ui_layer.render(&app.renderer, &ui_font, ctx);

        try app.endFrame();
    }
}

fn handleInput(state: *EditorState, app: *App) void {
    _ = state;
    _ = app;
}
fn drawViewport(state: *EditorState, app: *App) void {
    _ = state;
    _ = app;
}
