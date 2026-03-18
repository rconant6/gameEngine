const std = @import("std");
const rend = @import("renderer");
const ShapeData = rend.ShapeData;
const Color = rend.Color;
const Colors = rend.Colors;
const TaggedColor = rend.TaggedColor;
const plat = @import("platform");
const App = @import("app").App;
const Canvas = @import("Canvas.zig");
const PixelCell = Canvas.PixelCell;
const debug = @import("debug");
const log = debug.log;
const ZixelState = @import("ZixelState.zig");
const ColorLibrary = rend.ColorLibrary;
const Hue = rend.Hue;
const Tone = rend.Tone;
const Saturation = rend.Saturation;
const Temperature = rend.Temperature;
const Palette = @import("Palette.zig");
const layout = @import("Layout.zig");
const Region = layout.Region;
const InfoBar = @import("InfoBar.zig");
const ToolBar = @import("ToolBar.zig");
const assets = @import("assets");
const Font = assets.Font;
const ui = @import("ui");
const WidgetNode = ui.WidgetNode;
const UIManager = ui.UIManager;

const logical_width: i32 = 1920;
const logical_height: i32 = 1088;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try App.init(allocator, .{
        .title = "Zixel Art",
        .width = logical_width,
        .height = logical_height,
    });
    defer app.deinit();

    // Load the embedded font
    var ui_font = Font.initFromMemory(allocator, assets.embedded_default_font) catch |err| {
        log.err(.application, "Failed to load font: {any}", .{err});
        @panic("Cannot load font");
    };
    defer ui_font.deinit();

    const size = ui_font.measureText("Hello World", 24.0);
    log.info(.assets, "Font: width: {d}, height {d}", .{ size.x, size.y });

    log.debug(
        .application,
        "Number of Colors in library: {d}",
        .{ColorLibrary.getAllColors().len},
    );

    // UI
    var ui_manager: UIManager = .init(allocator);
    var toolbar_manager: UIManager = .init(allocator);
    var palette_manager: UIManager = .init(allocator);

    // Build canvas grid
    const canvas = Canvas.init(allocator, layout.canvas, 64) catch |err| {
        log.err(
            .application,
            "Unable to create Canvas: {any}",
            .{err},
        );
        @panic("Cannot create a canvas");
    };
    log.info(.application, "Created canvas of {d}x{d}", .{ 64, 64 });
    defer canvas.deinit();

    const color_name = "FOOD_PEACH";
    const active_color = ColorLibrary.findByName(color_name) orelse blk: {
        log.err(.application, "Active Color was not found: {s}", .{color_name});
        break :blk TaggedColor.from(Colors.MAGENTA, color_name);
    };
    log.debug(.application, "Default Color: {s}", .{active_color.name});

    var state: ZixelState = .{
        .canvas = canvas,
        .active_color = active_color.color,
        .active_color_name = active_color.name,
        .active_tool = .pencil,
    };

    const ctx: rend.RenderContext = .{
        .camera_loc = .{ .x = 0, .y = 0 },
        .height = logical_height,
        .width = logical_width,
        .ortho_size = logical_height / 2,
    };

    var str_buf: [256]u8 = undefined;
    while (app.isRunning()) {
        try app.beginFrame();

        app.renderer.setClearColor(Colors.DARK_GRAY);
        app.renderer.clear();

        ui_manager.rebuild();
        toolbar_manager.rebuild();
        palette_manager.rebuild();

        if (app.kb.isPressed(.Esc)) break;
        if (app.kb.isPressed(.C)) canvas.clear();
        const mouse_pos = app.mouse.position;
        const screen_x: i32 = @intFromFloat(mouse_pos.x);
        const screen_y: i32 = @intFromFloat(mouse_pos.y);
        const pos = screenToCanvas(canvas, screen_x, screen_y);
        if (pos) |p| {
            state.cursor_x = p.x;
            state.cursor_y = p.y;

            if (app.mouse.buttons.isPressed(.Left))
                canvas.setPixel(&state);
            if (app.mouse.buttons.isPressed(.Right))
                canvas.clearPixel(&state);
        } else {
            state.cursor_x = null;
            state.cursor_y = null;
        }

        for (state.canvas.pixels) |cell| {
            app.renderer.drawGeometry(
                cell.shape,
                null,
                cell.color,
                Colors.BLACK,
                1.0,
                ctx,
            );
        }

        const info_bar_root = InfoBar.buildTree(
            ui_manager.allocator(),
            &state,
            &str_buf,
        );
        ui_manager.setRoot(info_bar_root);
        ui_manager.layoutAt(
            layout.info_bar.x,
            layout.info_bar.y,
            layout.info_bar.width,
            layout.info_bar.height,
        );
        ui_manager.render(&app.renderer, &ui_font, ctx);
        const tool_bar_root = ToolBar.buildTree(toolbar_manager.allocator(), &state);
        toolbar_manager.setRoot(tool_bar_root);
        toolbar_manager.layoutAt(
            layout.toolbar.x,
            layout.toolbar.y,
            layout.toolbar.width,
            layout.toolbar.height,
        );
        toolbar_manager.processInput(
            app.mouse.position.x,
            app.mouse.position.y,
            app.mouse.buttons.isPressed(.Left),
            app.mouse.buttons.isReleased(.Left),
        );
        const palette_root = Palette.buildTree(palette_manager.allocator(), &state);
        palette_manager.setRoot(palette_root);
        palette_manager.layoutAt(
            layout.palette.x,
            layout.palette.y,
            layout.palette.width,
            layout.palette.height,
        );
        palette_manager.processInput(
            app.mouse.position.x,
            app.mouse.position.y,
            app.mouse.buttons.isPressed(.Left),
            app.mouse.buttons.isReleased(.Left),
        );

        // Poll palette clicks and update active color
        for (0..Palette.palette_size) |i| {
            if (palette_manager.getState(Palette.color_ids[i])) |ws| {
                switch (ws.*) {
                    .flags => |*bits| {
                        if (bits.* & ui.WidgetState.pressed != 0) {
                            state.active_color = Palette.colors[i];
                            state.active_color_name = if (ColorLibrary.findByColor(Palette.colors[i])) |tc|
                                tc.name
                            else
                                "custom";
                            bits.* &= ~ui.WidgetState.pressed;
                        }
                    },
                    else => {},
                }
            }
        }

        // Poll toolbar clicks and update active tool
        const Tool = @import("tool.zig").Tool;
        const tool_map = [_]struct { id: []const u8, tool: Tool }{
            .{ .id = "ck_pencil", .tool = .pencil },
            .{ .id = "ck_eraser", .tool = .erase },
            .{ .id = "ck_fill", .tool = .fill },
            .{ .id = "ck_line", .tool = .line },
            .{ .id = "ck_picker", .tool = .picker },
        };
        for (&tool_map) |entry| {
            if (toolbar_manager.getState(entry.id)) |ws| {
                switch (ws.*) {
                    .flags => |*bits| {
                        if (bits.* & ui.WidgetState.pressed != 0) {
                            state.active_tool = entry.tool;
                            bits.* &= ~ui.WidgetState.pressed;
                        }
                    },
                    else => {},
                }
            }
        }

        toolbar_manager.render(&app.renderer, &ui_font, ctx);
        palette_manager.render(&app.renderer, &ui_font, ctx);
        try app.endFrame();
    }
    palette_manager.deinit();
    toolbar_manager.deinit();
    ui_manager.deinit();
}

pub fn screenToCanvas(self: *const Canvas, screen_x: i32, screen_y: i32) ?struct { x: usize, y: usize } {
    if (screen_x < 0 or screen_y < 0) return null;

    const ux: usize = @intCast(screen_x);
    const uy: usize = @intCast(screen_y);

    if (ux < self.x_offset or uy < self.y_offset) return null;
    const canvas_x = (ux - self.x_offset) / self.pixel_size;
    const canvas_y = (uy - self.y_offset) / self.pixel_size;

    if (canvas_x >= self.pixel_count or canvas_y >= self.pixel_count) return null;
    return .{ .x = canvas_x, .y = canvas_y };
}
