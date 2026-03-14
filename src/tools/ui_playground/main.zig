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
    var test6 = ui.UIManager.init(allocator);
    defer test6.deinit();
    var test7 = ui.UIManager.init(allocator);
    defer test7.deinit();
    var test8 = ui.UIManager.init(allocator);
    defer test8.deinit();

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

        // ────────────────────────────────────────
        // Test 6: RGB Color Picker (3 sliders + swatch)
        // Expect: three labeled sliders (R, G, B) stacked
        //         vertically, with a color swatch panel
        //         showing the composed color.
        //         Slider state managed by UIManager via .value kind.
        // ────────────────────────────────────────
        test6.rebuild();
        {
            const a = test6.allocator();

            // Read current slider values from state map (persists across frames)
            const r_val: f32 = if (test6.getState("slider_r")) |s| @floatCast(s.value.val) else 0.5;
            const g_val: f32 = if (test6.getState("slider_g")) |s| @floatCast(s.value.val) else 0.5;
            const b_val: f32 = if (test6.getState("slider_b")) |s| @floatCast(s.value.val) else 0.5;

            const swatch_color: Color = .initRgba(
                @intFromFloat(r_val * 255.0),
                @intFromFloat(g_val * 255.0),
                @intFromFloat(b_val * 255.0),
                255,
            );

            // Build 3 slider rows: each is an HStack of [Label, Slider]
            var rows = try a.alloc(ui.WidgetNode, 4); // 3 slider rows + 1 swatch

            // --- R slider row ---
            var r_children = try a.alloc(ui.WidgetNode, 2);
            r_children[0] = .{
                .widget = .{ .Label = .{
                    .text = "R",
                    .font = &font,
                    .font_scale = 20.0,
                    .color = Colors.RED,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };
            r_children[1] = .{
                .widget = .{ .Slider = .{
                    .id = "slider_r",
                    .min = 0.0,
                    .max = 1.0,
                    .track_color = Colors.CHARCOAL,
                    .fill_color = Colors.RED,
                    .thumb_color = Colors.WHITE,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };
            rows[0] = .{
                .widget = .{ .HStack = .{
                    .children = r_children,
                    .spacing = 10,
                    .cross_axis = .center,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };

            // --- G slider row ---
            var g_children = try a.alloc(ui.WidgetNode, 2);
            g_children[0] = .{
                .widget = .{ .Label = .{
                    .text = "G",
                    .font = &font,
                    .font_scale = 20.0,
                    .color = Colors.GREEN,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };
            g_children[1] = .{
                .widget = .{ .Slider = .{
                    .id = "slider_g",
                    .min = 0.0,
                    .max = 1.0,
                    .track_color = Colors.CHARCOAL,
                    .fill_color = Colors.GREEN,
                    .thumb_color = Colors.WHITE,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };
            rows[1] = .{
                .widget = .{ .HStack = .{
                    .children = g_children,
                    .spacing = 10,
                    .cross_axis = .center,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };

            // --- B slider row ---
            var b_children = try a.alloc(ui.WidgetNode, 2);
            b_children[0] = .{
                .widget = .{ .Label = .{
                    .text = "B",
                    .font = &font,
                    .font_scale = 20.0,
                    .color = Colors.BLUE,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };
            b_children[1] = .{
                .widget = .{ .Slider = .{
                    .id = "slider_b",
                    .min = 0.0,
                    .max = 1.0,
                    .track_color = Colors.CHARCOAL,
                    .fill_color = Colors.BLUE,
                    .thumb_color = Colors.WHITE,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };
            rows[2] = .{
                .widget = .{ .HStack = .{
                    .children = b_children,
                    .spacing = 10,
                    .cross_axis = .center,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };

            // --- Color swatch ---
            const swatch_label = try a.create(ui.WidgetNode);
            swatch_label.* = .{
                .widget = .{ .Label = .{
                    .text = "Preview",
                    .font = &font,
                    .font_scale = 18.0,
                    .color = Colors.WHITE,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };
            rows[3] = .{
                .widget = .{ .Panel = .{
                    .child = swatch_label,
                    .background = swatch_color,
                    .border_color = Colors.WHITE,
                    .border_width = 1,
                    .padding = ui.EdgeInsets.symmetric(20, 8),
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };

            // Wrap all rows in a VStack
            const vstack = try a.create(ui.WidgetNode);
            vstack.* = .{
                .widget = .{ .VStack = .{
                    .children = rows,
                    .spacing = 6,
                    .cross_axis = .start,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };

            // Outer panel
            const panel = try a.create(ui.WidgetNode);
            panel.* = .{
                .widget = .{ .Panel = .{
                    .child = vstack,
                    .background = Colors.LIGHT_GRAY,
                    .border_color = Colors.WHITE,
                    .border_width = 1,
                    .padding = ui.EdgeInsets.all(12),
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };

            test6.setRoot(panel);
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
        //         with spacers absorbing remaining space equally
        //         inside a 1500px-wide panel at (340, 280)
        // ────────────────────────────────────────
        test7.rebuild();
        {
            const a = test7.allocator();

            var items = try a.alloc(ui.WidgetNode, 5); // label, spacer, label, spacer, label
            items[0] = .{
                .widget = .{ .Label = .{
                    .text = "File",
                    .font = &font,
                    .font_scale = 22.0,
                    .color = Colors.WHITE,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };
            items[1] = .{
                .widget = .{ .Spacer = .{
                    .min_size = 1,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };
            items[2] = .{
                .widget = .{ .Label = .{
                    .text = "Edit",
                    .font = &font,
                    .font_scale = 22.0,
                    .color = Colors.WHITE,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };
            items[3] = .{
                .widget = .{ .Spacer = .{
                    .min_size = 1,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };
            items[4] = .{
                .widget = .{ .Label = .{
                    .text = "View",
                    .font = &font,
                    .font_scale = 22.0,
                    .color = Colors.WHITE,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };

            const hstack = try a.create(ui.WidgetNode);
            hstack.* = .{
                .widget = .{ .HStack = .{
                    .children = items,
                    .spacing = 10,
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

            test7.setRoot(panel);
            test7.layoutAt(340, 280, 500, 50);
            test7.render(&app.renderer, &font, ctx);
        }

        // ────────────────────────────────────────
        // Test 8: Spacer — flex spacers in a VStack
        // Expect: "Top" at top, "Middle" centered, "Bottom" at bottom
        //         with spacers absorbing remaining vertical space equally
        //         inside a 300px-tall panel at (340, 350)
        // ────────────────────────────────────────
        test8.rebuild();
        {
            const a = test8.allocator();

            var items = try a.alloc(ui.WidgetNode, 5);
            items[0] = .{
                .widget = .{ .Label = .{
                    .text = "Top",
                    .font = &font,
                    .font_scale = 22.0,
                    .color = Colors.WHITE,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };
            items[1] = .{
                .widget = .{ .Spacer = .{
                    .min_size = null,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };
            items[2] = .{
                .widget = .{ .Label = .{
                    .text = "Middle",
                    .font = &font,
                    .font_scale = 22.0,
                    .color = Colors.WHITE,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };
            items[3] = .{
                .widget = .{ .Spacer = .{
                    .min_size = null,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };
            items[4] = .{
                .widget = .{ .Label = .{
                    .text = "Bottom",
                    .font = &font,
                    .font_scale = 22.0,
                    .color = Colors.WHITE,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };

            const vstack = try a.create(ui.WidgetNode);
            vstack.* = .{
                .widget = .{ .VStack = .{
                    .children = items,
                    .spacing = 4,
                    .cross_axis = .start,
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };

            const panel = try a.create(ui.WidgetNode);
            panel.* = .{
                .widget = .{ .Panel = .{
                    .child = vstack,
                    .background = Colors.CHARCOAL,
                    .border_color = Colors.WHITE,
                    .border_width = 1,
                    .padding = ui.EdgeInsets.all(12),
                } },
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            };

            test8.setRoot(panel);
            test8.layoutAt(340, 350, 200, 300);
            test8.render(&app.renderer, &font, ctx);
        }

        try app.endFrame();
    }
}
