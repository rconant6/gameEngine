//! UI Playground — visual testbed for the widget system.
//!
//! Exercises every widget and layout feature as it's built.
//! Each test case is positioned at a known location so you can
//! visually confirm layout, padding, spacing, and nesting.
//!
//! Run with: zig build ui

const std = @import("std");
const rend = @import("renderer");
const Colors = rend.Colors;
const Color = rend.Color;
const RenderContext = rend.RenderContext;
const App = @import("app").App;
const debug = @import("debug");
const log = debug.log;
const assets = @import("assets");
const Font = assets.Font;
const ui = @import("ui");

const logical_width: i32 = 1280;
const logical_height: i32 = 720;
const screen_w: f32 = @floatFromInt(logical_width);
const screen_h: f32 = @floatFromInt(logical_height);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try App.init(allocator, .{
        .title = "UI Playground",
        .width = @intCast(logical_width),
        .height = @intCast(logical_height),
    });
    defer app.deinit();

    var font = Font.initFromMemory(allocator, assets.embedded_default_font) catch |err| {
        log.err(.application, "Failed to load font: {any}", .{err});
        @panic("Cannot load default engine font");
    };
    defer font.deinit();

    const ctx: RenderContext = .{
        .camera_loc = .{ .x = 0, .y = 0 },
        .height = logical_height,
        .width = logical_width,
        .ortho_size = logical_height / 2,
    };

    // One UIManager per independent test region
    var test1 = ui.UIManager.init(allocator);
    defer test1.deinit();
    var test2 = ui.UIManager.init(allocator);
    defer test2.deinit();
    var test3 = ui.UIManager.init(allocator);
    defer test3.deinit();
    var test4 = ui.UIManager.init(allocator);
    defer test4.deinit();
    var test5 = ui.UIManager.init(allocator);
    defer test5.deinit();

    while (app.isRunning()) {
        try app.beginFrame();

        app.renderer.setClearColor(Colors.DARK_GRAY);
        app.renderer.clear();

        if (app.kb.isPressed(.Esc)) break;

        // ────────────────────────────────────────
        // Test 1: Single Label
        // Expect: white text at (20, 20)
        // ────────────────────────────────────────
        test1.rebuild();
        {
            const a = test1.allocator();
            const node = try a.create(ui.WidgetNode);
            node.* = .{
                .widget = .{ .Label = .{
                    .text = "Test 1: Single Label",
                    .font = &font,
                    .font_scale = 24.0,
                    .color = Colors.WHITE,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };
            test1.setRoot(node);
            test1.layoutAt(20, 20, 400, 40);
            test1.render(&app.renderer, &font, ctx);
        }

        // ────────────────────────────────────────
        // Test 2: Panel wrapping a Label
        // Expect: charcoal background rect with
        //         white outline, text inset by padding
        //         at (20, 80)
        // ────────────────────────────────────────
        test2.rebuild();
        {
            const a = test2.allocator();
            const label = try a.create(ui.WidgetNode);
            label.* = .{
                .widget = .{ .Label = .{
                    .text = "Test 2: Panel + Label",
                    .font = &font,
                    .font_scale = 24.0,
                    .color = Colors.WHITE,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };
            const panel = try a.create(ui.WidgetNode);
            panel.* = .{
                .widget = .{ .Panel = .{
                    .child = label,
                    .background = Colors.CHARCOAL,
                    .border_color = Colors.WHITE,
                    .border_width = 1,
                    .padding = ui.EdgeInsets.all(12),
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };
            test2.setRoot(panel);
            test2.layoutAt(20, 80, 500, 60);
            test2.render(&app.renderer, &font, ctx);
        }

        // ────────────────────────────────────────
        // Test 3: HStack with three Labels
        // Expect: three labels in a row with 20px
        //         gaps, inside a panel at (20, 180)
        // ────────────────────────────────────────
        test3.rebuild();
        {
            const a = test3.allocator();
            var labels = try a.alloc(ui.WidgetNode, 3);
            labels[0] = .{
                .widget = .{ .Label = .{
                    .text = "LEFT",
                    .font = &font,
                    .font_scale = 24.0,
                    .color = Colors.UI_BUTTON_TEXT,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };
            labels[1] = .{
                .widget = .{ .Label = .{
                    .text = "CENTER",
                    .font = &font,
                    .font_scale = 24.0,
                    .color = Colors.UI_TEXT_INFO,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };
            labels[2] = .{
                .widget = .{ .Label = .{
                    .text = "RIGHT",
                    .font = &font,
                    .font_scale = 24.0,
                    .color = Colors.UI_BUTTON_NORMAL,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };

            const hstack = try a.create(ui.WidgetNode);
            hstack.* = .{
                .widget = .{ .HStack = .{
                    .children = labels,
                    .spacing = 20,
                    .cross_axis = .center,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };

            const panel = try a.create(ui.WidgetNode);
            panel.* = .{
                .widget = .{ .Panel = .{
                    .child = hstack,
                    .background = Colors.CHARCOAL,
                    .border_color = Colors.WHITE,
                    .border_width = 1,
                    .padding = ui.EdgeInsets.symmetric(16, 8),
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };

            test3.setRoot(panel);
            test3.layoutAt(20, 180, 600, 50);
            test3.render(&app.renderer, &font, ctx);
        }

        // ────────────────────────────────────────
        // Test 4: Info bar simulation (bottom of screen)
        // Expect: full-width bar at bottom with
        //         dynamic mouse coords
        // ────────────────────────────────────────
        test4.rebuild();
        {
            const a = test4.allocator();
            var info_labels = try a.alloc(ui.WidgetNode, 4);

            info_labels[0] = .{
                .widget = .{ .Label = .{
                    .text = "PENCIL",
                    .font = &font,
                    .font_scale = 22.0,
                    .color = Colors.UI_BUTTON_TEXT,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };
            info_labels[1] = .{
                .widget = .{ .Label = .{
                    .text = "FOOD_PEACH",
                    .font = &font,
                    .font_scale = 22.0,
                    .color = Colors.UI_BUTTON_TEXT,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };
            info_labels[2] = .{
                .widget = .{ .Label = .{
                    .text = "64x64",
                    .font = &font,
                    .font_scale = 22.0,
                    .color = Colors.UI_TEXT_INFO,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };

            var coord_buf: [64]u8 = undefined;
            const coord_text = std.fmt.bufPrint(
                &coord_buf,
                "[{d:.0}, {d:.0}]",
                .{ app.mouse.position.x, app.mouse.position.y },
            ) catch "???";
            info_labels[3] = .{
                .widget = .{ .Label = .{
                    .text = coord_text,
                    .font = &font,
                    .font_scale = 22.0,
                    .color = Colors.UI_BUTTON_NORMAL,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };

            const hstack = try a.create(ui.WidgetNode);
            hstack.* = .{
                .widget = .{ .HStack = .{
                    .children = info_labels,
                    .spacing = 30,
                    .cross_axis = .center,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };

            const bar = try a.create(ui.WidgetNode);
            bar.* = .{
                .widget = .{ .Panel = .{
                    .child = hstack,
                    .background = Colors.CHARCOAL,
                    .border_color = null,
                    .border_width = 0,
                    .padding = ui.EdgeInsets.symmetric(16, 0),
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };

            test4.setRoot(bar);
            test4.layoutAt(0, screen_h - 40, screen_w, 40);
            test4.render(&app.renderer, &font, ctx);
        }

        // ────────────────────────────────────────
        // Test 5: Buttons with hover/press states
        // Expect: two buttons side-by-side in a panel,
        //         hover changes color, click fires callback.
        //         State managed by UIManager via string id.
        // ────────────────────────────────────────
        test5.rebuild();
        {
            const a = test5.allocator();
            // const widgets = ui.Widgets;

            var buttons = try a.alloc(ui.WidgetNode, 2);
            buttons[0] = .{
                .widget = .{ .Button = .{
                    .id = "btn_save",
                    .text = "Save",
                    .font = &font,
                    .font_scale = 24.0,
                    .colors = .{
                        .normal = Colors.UI_BUTTON_NORMAL,
                        .hovered = Colors.UI_BUTTON_HOVER,
                        .pressed = Colors.UI_BUTTON_PRESSED,
                        .text = Colors.UI_BUTTON_TEXT,
                    },
                    .on_click = null,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };
            buttons[1] = .{
                .widget = .{ .Button = .{
                    .id = "btn_clear",
                    .text = "Clear",
                    .font = &font,
                    .font_scale = 24.0,
                    .colors = .{
                        .normal = Colors.CHARCOAL,
                        .hovered = Colors.BLUE,
                        .pressed = Colors.RED,
                        .text = Colors.WHITE,
                    },
                    .on_click = null,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };

            const hstack = try a.create(ui.WidgetNode);
            hstack.* = .{
                .widget = .{ .HStack = .{
                    .children = buttons,
                    .spacing = 12,
                    .cross_axis = .center,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };

            const panel = try a.create(ui.WidgetNode);
            panel.* = .{
                .widget = .{ .Panel = .{
                    .child = hstack,
                    .background = Colors.DARK_GRAY,
                    .border_color = Colors.WHITE,
                    .border_width = 1,
                    .padding = ui.EdgeInsets.all(10),
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };

            test5.setRoot(panel);
            test5.layoutAt(20, 280, 400, 60);

            // Process input — UIManager looks up ButtonState by id,
            // updates hover/pressed, fires on_click on mouse_up
            test5.processInput(
                app.mouse.position.x,
                app.mouse.position.y,
                app.mouse.buttons.isPressed(.Left),
                app.mouse.buttons.isReleased(.Left),
            );

            test5.render(&app.renderer, &font, ctx);
        }

        try app.endFrame();
    }
}
