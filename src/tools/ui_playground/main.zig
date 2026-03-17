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
const make = ui.make;

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
    var test6 = ui.UIManager.init(allocator);
    defer test6.deinit();
    var test7 = ui.UIManager.init(allocator);
    defer test7.deinit();
    var test8 = ui.UIManager.init(allocator);
    defer test8.deinit();
    var test9 = ui.UIManager.init(allocator);
    defer test9.deinit();
    var test10 = ui.UIManager.init(allocator);
    defer test10.deinit();

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
            test1.setRoot(make.label(a, "Test 1: Single Label", .{ .color = Colors.UI_HEALTH_CRITICAL }));
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
            test2.setRoot(
                make.panel(a, make.label(a, "Test 2: Panel + Label", .{}), .{
                    .padding = ui.EdgeInsets.all(12),
                }),
            );
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
            test3.setRoot(
                make.panel(a, make.hstack(a, &.{
                    make.label(a, "LEFT", .{ .color = Colors.UI_BUTTON_TEXT }),
                    make.label(a, "CENTER", .{ .color = Colors.UI_TEXT_INFO }),
                    make.label(a, "RIGHT", .{ .color = Colors.UI_BUTTON_NORMAL }),
                }, .{ .spacing = 20 }), .{
                    .padding = ui.EdgeInsets.symmetric(16, 8),
                }),
            );
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
            var coord_buf: [64]u8 = undefined;
            const coord_text = std.fmt.bufPrint(
                &coord_buf,
                "[{d:.0}, {d:.0}]",
                .{ app.mouse.position.x, app.mouse.position.y },
            ) catch "???";

            test4.setRoot(
                make.panel(a, make.hstack(a, &.{
                    make.label(a, "PENCIL", .{ .font_scale = 22.0, .color = Colors.UI_BUTTON_TEXT }),
                    make.label(a, "FOOD_PEACH", .{ .font_scale = 22.0, .color = Colors.UI_BUTTON_TEXT }),
                    make.label(a, "64x64", .{ .font_scale = 22.0, .color = Colors.UI_TEXT_INFO }),
                    make.label(a, coord_text, .{ .font_scale = 22.0, .color = Colors.UI_BUTTON_NORMAL }),
                }, .{ .spacing = 30 }), .{
                    .border_color = Colors.CHARCOAL,
                    .border_width = 0,
                    .padding = ui.EdgeInsets.symmetric(16, 0),
                }),
            );
            test4.layoutAt(0, screen_h - 40, screen_w, 40);
            test4.render(&app.renderer, &font, ctx);
        }

        // ────────────────────────────────────────
        // Test 5: Buttons with hover/press states
        // Expect: two buttons side-by-side in a panel,
        //         hover changes color, click fires callback.
        // ────────────────────────────────────────
        test5.rebuild();
        {
            const a = test5.allocator();
            test5.setRoot(
                make.panel(a, make.hstack(a, &.{
                    make.button(a, "btn_save", "Save", .{}),
                    make.button(a, "btn_clear", "Clear", .{
                        .colors = .{
                            .normal = Colors.CHARCOAL,
                            .hovered = Colors.BLUE,
                            .pressed = Colors.RED,
                            .text = Colors.WHITE,
                        },
                    }),
                }, .{ .spacing = 12 }), .{
                    .background = Colors.DARK_GRAY,
                    .padding = ui.EdgeInsets.all(10),
                }),
            );
            test5.layoutAt(20, 280, 400, 60);
            test5.processInput(
                app.mouse.position.x,
                app.mouse.position.y,
                app.mouse.buttons.isPressed(.Left),
                app.mouse.buttons.isReleased(.Left),
            );
            test5.render(&app.renderer, &font, ctx);
        }

        // ────────────────────────────────────────
        // Test 6: RGB Color Picker (3 sliders + swatch)
        // Expect: three labeled sliders (R, G, B) stacked
        //         vertically, with a color swatch panel
        //         showing the composed color.
        // ────────────────────────────────────────
        test6.rebuild();
        {
            const a = test6.allocator();

            const r_val: f32 = if (test6.getState("slider_r")) |s| @floatCast(s.value.val) else 0.5;
            const g_val: f32 = if (test6.getState("slider_g")) |s| @floatCast(s.value.val) else 0.5;
            const b_val: f32 = if (test6.getState("slider_b")) |s| @floatCast(s.value.val) else 0.5;

            const swatch_color: Color = .initRgba(
                @intFromFloat(r_val * 255.0),
                @intFromFloat(g_val * 255.0),
                @intFromFloat(b_val * 255.0),
                255,
            );

            test6.setRoot(
                make.panel(a, make.vstack(a, &.{
                    make.hstack(a, &.{
                        make.label(a, "R", .{ .font_scale = 20.0, .color = Colors.RED }),
                        make.slider(a, "slider_r", .{ .fill_color = Colors.RED }),
                    }, .{ .spacing = 10 }),
                    make.hstack(a, &.{
                        make.label(a, "G", .{ .font_scale = 20.0, .color = Colors.GREEN }),
                        make.slider(a, "slider_g", .{ .fill_color = Colors.GREEN }),
                    }, .{ .spacing = 10 }),
                    make.hstack(a, &.{
                        make.label(a, "B", .{ .font_scale = 20.0, .color = Colors.BLUE }),
                        make.slider(a, "slider_b", .{ .fill_color = Colors.BLUE }),
                    }, .{ .spacing = 10 }),
                    make.panel(a, make.label(a, "Preview", .{ .font_scale = 18.0 }), .{
                        .background = swatch_color,
                        .padding = ui.EdgeInsets.symmetric(20, 8),
                    }),
                }, .{ .spacing = 6 }), .{
                    .background = Colors.LIGHT_GRAY,
                    .padding = ui.EdgeInsets.all(12),
                }),
            );
            test6.layoutAt(20, 370, 300, 200);
            test6.processInput(
                app.mouse.position.x,
                app.mouse.position.y,
                app.mouse.buttons.isPressed(.Left),
                app.mouse.buttons.isReleased(.Left),
            );
            test6.render(&app.renderer, &font, ctx);
        }

        // ────────────────────────────────────────
        // Test 7: Spacer — flex spacers in an HStack
        // Expect: "File" left, "Edit" centered, "View" right
        // ────────────────────────────────────────
        test7.rebuild();
        {
            const a = test7.allocator();
            test7.setRoot(
                make.panel(a, make.hstack(a, &.{
                    make.label(a, "File", .{ .font_scale = 22.0 }),
                    make.spacer(a, 1),
                    make.label(a, "Edit", .{ .font_scale = 22.0 }),
                    make.spacer(a, 1),
                    make.label(a, "View", .{ .font_scale = 22.0 }),
                }, .{ .spacing = 10 }), .{
                    .padding = ui.EdgeInsets.symmetric(16, 8),
                }),
            );
            test7.layoutAt(340, 280, 500, 50);
            test7.render(&app.renderer, &font, ctx);
        }

        // ────────────────────────────────────────
        // Test 8: Spacer — flex spacers in a VStack
        // Expect: "Top" at top, "Middle" centered, "Bottom" at bottom
        // ────────────────────────────────────────
        test8.rebuild();
        {
            const a = test8.allocator();
            test8.setRoot(
                make.panel(a, make.vstack(a, &.{
                    make.label(a, "Top", .{ .font_scale = 22.0 }),
                    make.spacer(a, null),
                    make.label(a, "Middle", .{ .font_scale = 22.0 }),
                    make.spacer(a, null),
                    make.label(a, "Bottom", .{ .font_scale = 22.0 }),
                }, .{ .spacing = 4 }), .{
                    .padding = ui.EdgeInsets.all(12),
                }),
            );
            test8.layoutAt(340, 350, 200, 300);
            test8.render(&app.renderer, &font, ctx);
        }

        // ────────────────────────────────────────
        // Test 9: Grid — 12 colored panels in a 4-column grid
        // Expect: 4 columns x 3 rows of colored squares
        // ────────────────────────────────────────
        test9.rebuild();
        {
            const a = test9.allocator();
            const grid_colors = [12]Color{
                Colors.RED,     Colors.ORANGE, Colors.YELLOW, Colors.LIME,
                Colors.GREEN,   Colors.CYAN,   Colors.BLUE,   Colors.PURPLE,
                Colors.MAGENTA, Colors.PINK,   Colors.BROWN,  Colors.DARK_GREEN,
            };

            var cells: [12]*ui.WidgetNode = undefined;
            for (&cells, 0..) |*cell, i| {
                cell.* = make.panel(
                    a,
                    make.label(a, "", .{ .font_scale = 1.0 }),
                    .{
                        .background = grid_colors[i],
                        .padding = ui.EdgeInsets.all(16),
                    },
                );
            }

            test9.setRoot(
                make.panel(a, make.grid(a, &cells, .{ .columns = 4 }), .{
                    .padding = ui.EdgeInsets.all(8),
                }),
            );
            test9.layoutAt(560, 350, 300, 300);
            test9.render(&app.renderer, &font, ctx);
        }

        // ────────────────────────────────────────
        // Test 10: Chicklets — small icon-sized buttons
        // Expect: row of colored chicklets with hover/press
        //         states, inside a panel at (880, 280)
        // ────────────────────────────────────────
        test10.rebuild();
        {
            const a = test10.allocator();
            test10.setRoot(
                make.panel(a, make.hstack(a, &.{
                    make.chicklet(a, "ck_red", .{
                        .colors = .{
                            .not_selected = Colors.PASTEL_PINK,
                            .selected = Colors.TULIP_PINK,
                        },
                    }),
                    make.chicklet(a, "ck_green", .{
                        .colors = .{
                            .selected = Colors.GREEN,
                            .not_selected = Colors.LIME,
                        },
                    }),
                    make.chicklet(a, "ck_blue", .{
                        .colors = .{
                            .selected = Colors.BLUE,
                            .not_selected = Colors.CYAN,
                        },
                    }),
                    make.chicklet(a, "ck_default", .{}),
                }, .{ .spacing = 8 }), .{
                    .background = Colors.DARK_GRAY,
                    .padding = ui.EdgeInsets.all(10),
                }),
            );
            test10.layoutAt(880, 280, 200, 60);
            test10.processInput(
                app.mouse.position.x,
                app.mouse.position.y,
                app.mouse.buttons.isPressed(.Left),
                app.mouse.buttons.isReleased(.Left),
            );
            test10.render(&app.renderer, &font, ctx);
        }

        try app.endFrame();
    }
}
