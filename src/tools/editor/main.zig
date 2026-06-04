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
const core = @import("math");
const Memory = core.GameMemory;

const Hierarchy = @import("Hierarchy.zig");
const Inspector = @import("Inspector.zig");
const EditorState = @import("EditorState.zig");

const logical_width: i32 = 1920;
const logical_height: i32 = 1080;

pub fn main(init: std.process.Init) !void {
    const backing = init.gpa;
    const io = init.io;
    const env = init.environ_map;

    var app = try App.init(backing, io, env, .{
        .title = "Scene Editor",
        .width = logical_width,
        .height = logical_height,
    });
    defer app.deinit();

    const persistent = app.mem.persistent;
    // const frame = app.mem.frame;
    const temp = app.mem.temp;

    const eng = engine.Engine.init(&app);
    defer eng.deinit();

    var state = EditorState.init(persistent);
    defer state.deinit();

    // Load test scene for development
    const test_scene_src = @embedFile("test_scene.scene");
    const test_scene_src_z = try std.mem.concatWithSentinel(temp, u8, &.{test_scene_src}, 0);
    defer temp.free(test_scene_src_z);
    const parsed = scene_fmt.parseString(persistent, test_scene_src_z, "game.scene") catch |err| blk: {
        log.err(.application, "Failed to parse test scene: {any}", .{err});
        break :blk null;
    };
    if (parsed) |sf| {
        const sf_ptr = try persistent.create(scene_fmt.SceneFile);
        sf_ptr.* = sf;
        state.scene_file = sf_ptr;
    }

    var ui_font = Font.initFromMemory(persistent, assets.embedded_default_font) catch |err| {
        log.err(.application, "Failed to load font: {any}", .{err});
        @panic("Cannot load font");
    };
    defer ui_font.deinit();

    const size = ui_font.measureText("Hello World", 24.0);
    log.info(.assets, "Font: width: {d}, height {d}", .{ size.x, size.y });

    var ui_layer = UILayer.init(persistent);
    defer ui_layer.deinit();

    Hierarchy.setState(&state);
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
        flushHierarchySelection(&ui_layer, &state);
        ui_layer.render(&app.renderer, &ui_font, ctx);

        try app.endFrame();
    }
}

fn flushHierarchySelection(ui_layer: *UILayer, state: *EditorState) void {
    const sf = state.scene_file orelse return;
    flushDecls(ui_layer, state, sf.decls, null);
}

fn flushDecls(
    ui_layer: *UILayer,
    state: *EditorState,
    decls: []const scene_fmt.Declaration,
    scene_name: ?[]const u8,
) void {
    for (decls) |decl| {
        switch (decl) {
            .entity => |e| {
                var id_buf: [256]u8 = undefined;
                const id = std.fmt.bufPrint(
                    &id_buf,
                    "e:{s}:{s}",
                    .{ scene_name orelse "", e.name },
                ) catch continue;
                if (ui_layer.getState("hierarchy", id)) |ws| {
                    switch (ws.*) {
                        .flags => |*bits| {
                            if (bits.* & ui.WidgetState.pressed != 0) {
                                state.selected = .{
                                    .scene_name = scene_name,
                                    .entity_name = e.name,
                                };
                                bits.* &= ~ui.WidgetState.pressed;
                            }
                        },
                        else => {},
                    }
                }
            },
            .scene => |s| flushDecls(ui_layer, state, s.decls, s.name),
            else => {},
        }
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
