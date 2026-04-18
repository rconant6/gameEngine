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
const ColorSlider = @import("ColorSlider.zig");
const ColorPanel = @import("ColorPanel.zig");
const Palette = @import("Palette.zig");
const InfoBar = @import("InfoBar.zig");
const ToolBar = @import("ToolBar.zig");
const layout = @import("Layout.zig");
const Region = layout.Region;
const assets = @import("assets");
const zxl = @import("zxl");
const ZxlReader = zxl.ZxlReader;
const ZxlWriter = zxl.ZxlWriter;
const ZxlImage = zxl.ZxlImage;
const math = @import("math");
const Rgba = math.Rgba;
const Font = assets.Font;
const ui = @import("ui");
const WidgetNode = ui.WidgetNode;
const UIManager = ui.UIManager;
const UILayer = ui.UILayer;

const logical_width: i32 = 1920;
const logical_height: i32 = 1088;

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var app = try App.init(allocator, io, .{
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
    var ui_layer = UILayer.init(allocator);
    ui_layer.addView(
        "toolbar",
        .{ .x = 20, .y = 20, .width = 240, .height = 1048 },
        ToolBar.buildTree,
        .{},
    );
    ui_layer.addView(
        "palette",
        .{ .x = 1448, .y = 20, .width = 300, .height = 300 },
        Palette.buildTree,
        .{},
    );
    ui_layer.addView(
        "color_panel",
        .{ .x = 1448, .y = 320, .width = 300, .height = 300 },
        ColorPanel.buildTree,
        .{ .interactive = false },
    );
    ui_layer.addView(
        "color_slider",
        .{ .x = 1448, .y = 740, .width = 300, .height = 300 },
        ColorSlider.buildTree,
        .{},
    );
    ui_layer.addView(
        "info_bar",
        .{ .x = 0, .y = 1048, .width = 1920, .height = 40 },
        InfoBar.buildTree,
        .{ .interactive = false },
    );

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

    const color_name = "RED";
    const active_color = ColorLibrary.findByName(color_name) orelse blk: {
        log.err(.application, "Active Color was not found: {s}", .{color_name});
        break :blk TaggedColor.from(Colors.MAGENTA, color_name);
    };
    log.debug(.application, "Default Color: {s}", .{active_color.name});

    var state_buf: [256]u8 = undefined;
    var state: ZixelState = .{
        .canvas = canvas,
        .active_color = active_color.color,
        .active_color_name = active_color.name,
        .active_tool = .pencil,
        .bg_color = Colors.LIGHT_GRAY,
        .buf = &state_buf,
    };

    const ctx: rend.RenderContext = .{
        .camera_loc = .{ .x = 0, .y = 0 },
        .height = logical_height,
        .width = logical_width,
        .ortho_size = logical_height / 2,
    };

    var is_drawing = false;

    while (app.isRunning()) {
        try app.beginFrame();

        app.renderer.setClearColor(Colors.DARK_GRAY);
        app.renderer.clear();

        if (app.kb.isPressed(.Esc)) break;
        if (app.kb.isPressed(.C)) canvas.clear();

        // Undo / Redo (Cmd+Z / Cmd+Shift+Z) + Save/Load (Cmd+S / Cmd+O)
        if (app.kb.isDown(.LeftCmd) or app.kb.isDown(.RightCmd)) {
            if (app.kb.isPressed(.Z)) {
                if (app.kb.isDown(.LeftShift) or app.kb.isDown(.RightShift)) {
                    if (canvas.history.redo()) |cmd| cmd.redo(canvas);
                } else {
                    if (canvas.history.undo()) |cmd| cmd.undo(canvas);
                }
            }
            if (app.kb.isPressed(.S)) {
                saveCanvas(allocator, io, canvas);
            }
            if (app.kb.isPressed(.O)) {
                loadCanvas(allocator, io, canvas);
            }
        }

        const mouse_pos = app.mouse.position;
        const screen_x: i32 = @intFromFloat(mouse_pos.x);
        const screen_y: i32 = @intFromFloat(mouse_pos.y);
        const pos = screenToCanvas(canvas, screen_x, screen_y);
        if (pos) |p| {
            state.cursor_x = p.x;
            state.cursor_y = p.y;

            if (app.mouse.buttons.isPressed(.Left)) {
                is_drawing = true;
                canvas.onMouseDown(state.active_tool, p.x, p.y, state.active_color);
            } else if (is_drawing and app.mouse.buttons.isDown(.Left)) {
                canvas.onMouseDrag(state.active_tool, p.x, p.y, state.active_color);
            }

            if (app.mouse.buttons.isReleased(.Left) and is_drawing) {
                canvas.onMouseUp(state.active_tool);
                is_drawing = false;
            }
        } else {
            // Cursor left canvas — commit if mid-stroke
            if (is_drawing and app.mouse.buttons.isReleased(.Left)) {
                canvas.onMouseUp(state.active_tool);
                is_drawing = false;
            }
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
        ui_layer.update(
            &state,
            mouse_pos.x,
            mouse_pos.y,
            app.mouse.buttons.isPressed(.Left),
            app.mouse.buttons.isReleased(.Left),
        );

        // Poll toolbar clicks
        const Tool = @import("tool.zig").Tool;
        const tool_map = [_]struct { id: []const u8, tool: Tool }{
            .{ .id = "ck_pencil", .tool = .pencil },
            .{ .id = "ck_eraser", .tool = .erase },
            .{ .id = "ck_fill", .tool = .fill },
            .{ .id = "ck_line", .tool = .line },
            .{ .id = "ck_picker", .tool = .picker },
        };
        for (&tool_map) |entry| {
            if (ui_layer.getState("toolbar", entry.id)) |ws| {
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

        // Poll palette clicks
        for (0..Palette.palette_size) |i| {
            if (ui_layer.getState("palette", Palette.color_ids[i])) |ws| {
                switch (ws.*) {
                    .flags => |*bits| {
                        if (bits.* & ui.WidgetState.pressed != 0) {
                            const tagged_color = ColorLibrary.findByColor(
                                Palette.colors[i],
                            );
                            state.active_color = Palette.colors[i];
                            state.active_color_name =
                                if (tagged_color) |tc| tc.name else "CUSTOM";
                            bits.* &= ~ui.WidgetState.pressed;

                            // Sync sliders to new palette color
                            syncSlidersToColor(&ui_layer, state.active_color);
                        }
                    },
                    else => {},
                }
            }
        }

        // Poll RGB sliders
        {
            const r_ws = ui_layer.getState("color_slider", "slider_r");
            const g_ws = ui_layer.getState("color_slider", "slider_g");
            const b_ws = ui_layer.getState("color_slider", "slider_b");

            const r_active = if (r_ws) |ws| switch (ws.*) {
                .value => |v| v.flags & ui.WidgetState.dragging != 0,
                else => false,
            } else false;
            const g_active = if (g_ws) |ws| switch (ws.*) {
                .value => |v| v.flags & ui.WidgetState.dragging != 0,
                else => false,
            } else false;
            const b_active = if (b_ws) |ws| switch (ws.*) {
                .value => |v| v.flags & ui.WidgetState.dragging != 0,
                else => false,
            } else false;

            if (r_active or g_active or b_active) {
                const r_val: f32 = if (r_ws) |ws| switch (ws.*) {
                    .value => |v| @as(f32, @floatCast(v.val)),
                    else => 0,
                } else 0;
                const g_val: f32 = if (g_ws) |ws| switch (ws.*) {
                    .value => |v| @as(f32, @floatCast(v.val)),
                    else => 0,
                } else 0;
                const b_val: f32 = if (b_ws) |ws| switch (ws.*) {
                    .value => |v| @as(f32, @floatCast(v.val)),
                    else => 0,
                } else 0;

                state.active_color = Color.initRgba(
                    @intFromFloat(r_val * 255.0),
                    @intFromFloat(g_val * 255.0),
                    @intFromFloat(b_val * 255.0),
                    255,
                );
                state.active_color_name = "CUSTOM";

                // Sync HSV sliders to match
                syncHsvSliders(&ui_layer, state.active_color);
            }
        }

        // Poll HSV sliders
        {
            const h_ws = ui_layer.getState("color_slider", "slider_h");
            const s_ws = ui_layer.getState("color_slider", "slider_s");
            const v_ws = ui_layer.getState("color_slider", "slider_v");

            const h_active = if (h_ws) |ws| switch (ws.*) {
                .value => |v| v.flags & ui.WidgetState.dragging != 0,
                else => false,
            } else false;
            const s_active = if (s_ws) |ws| switch (ws.*) {
                .value => |v| v.flags & ui.WidgetState.dragging != 0,
                else => false,
            } else false;
            const v_active = if (v_ws) |ws| switch (ws.*) {
                .value => |v| v.flags & ui.WidgetState.dragging != 0,
                else => false,
            } else false;

            if (h_active or s_active or v_active) {
                const h_val: f32 = if (h_ws) |ws| switch (ws.*) {
                    .value => |v| @as(f32, @floatCast(v.val)),
                    else => 0,
                } else 0;
                const s_val: f32 = if (s_ws) |ws| switch (ws.*) {
                    .value => |v| @as(f32, @floatCast(v.val)),
                    else => 0,
                } else 0;
                const v_val: f32 = if (v_ws) |ws| switch (ws.*) {
                    .value => |v| @as(f32, @floatCast(v.val)),
                    else => 0,
                } else 0;

                state.active_color = Color.initHsva(
                    h_val * 360.0,
                    s_val,
                    v_val,
                    1.0,
                );
                state.active_color_name = "CUSTOM";

                // Sync RGB sliders to match
                syncRgbSliders(&ui_layer, state.active_color);
            }
        }

        ui_layer.render(&app.renderer, &ui_font, ctx);

        try app.endFrame();
    }

    ui_layer.deinit();
}

fn setSliderVal(layer: *UILayer, view: []const u8, id: []const u8, val: f16) void {
    if (layer.getState(view, id)) |ws| {
        ws.* = .{ .value = .{ .val = val } };
    }
}

fn syncRgbSliders(layer: *UILayer, color: Color) void {
    setSliderVal(layer, "color_slider", "slider_r", @as(f16, @floatFromInt(color.rgba.r)) / 255.0);
    setSliderVal(layer, "color_slider", "slider_g", @as(f16, @floatFromInt(color.rgba.g)) / 255.0);
    setSliderVal(layer, "color_slider", "slider_b", @as(f16, @floatFromInt(color.rgba.b)) / 255.0);
}

fn syncHsvSliders(layer: *UILayer, color: Color) void {
    setSliderVal(layer, "color_slider", "slider_h", @as(f16, @floatCast(color.hsva.h / 360.0)));
    setSliderVal(layer, "color_slider", "slider_s", @as(f16, @floatCast(color.hsva.s)));
    setSliderVal(layer, "color_slider", "slider_v", @as(f16, @floatCast(color.hsva.v)));
}

fn syncSlidersToColor(layer: *UILayer, color: Color) void {
    syncRgbSliders(layer, color);
    syncHsvSliders(layer, color);
}

const zxl_path = "output.zxl";

fn saveCanvas(allocator: std.mem.Allocator, io: std.Io, canvas: *const Canvas) void {
    const size: u16 = @intCast(canvas.pixel_count);

    var image = ZxlImage.init(allocator, "canvas") catch |err| {
        log.err(.application, "Failed to create ZxlImage: {any}", .{err});
        return;
    };
    defer image.deinit();

    // Build palette from canvas pixels
    const pixel_total = canvas.pixel_count * canvas.pixel_count;
    const indices = allocator.alloc(u8, pixel_total) catch |err| {
        log.err(.application, "Failed to alloc pixel indices: {any}", .{err});
        return;
    };
    defer allocator.free(indices);

    for (0..pixel_total) |i| {
        const c = canvas.pixels[i].color;
        const rgba = Rgba{ .r = c.rgba.r, .g = c.rgba.g, .b = c.rgba.b, .a = c.rgba.a };

        // Transparent pixels map to index 0
        if (rgba.a == 0) {
            indices[i] = 0;
            continue;
        }

        // Find or add color to palette
        if (image.palette.findColor(rgba)) |idx| {
            indices[i] = idx;
        } else {
            const idx = image.palette.addColor(rgba);
            if (idx == 0) {
                log.err(.application, "Palette full, too many unique colors", .{});
                return;
            }
            indices[i] = idx;
        }
    }

    image.addFrame("canvas", size, size, indices, 0, 0, 0) catch |err| {
        log.err(.application, "Failed to add frame: {any}", .{err});
        return;
    };

    ZxlWriter.toFile(allocator, io, &image, zxl_path) catch |err| {
        log.err(.application, "Failed to save .zxl: {any}", .{err});
        return;
    };

    log.info(.application, "Saved {s} ({d} palette colors)", .{ zxl_path, image.palette.count });
}

fn loadCanvas(allocator: std.mem.Allocator, io: std.Io, canvas: *Canvas) void {
    var image = ZxlReader.fromFile(allocator, io, zxl_path) catch |err| {
        log.err(.application, "Failed to load {s}: {any}", .{ zxl_path, err });
        return;
    };
    defer image.deinit();

    const frame = image.getFrame(0) orelse {
        log.err(.application, "No frames in {s}", .{zxl_path});
        return;
    };

    // Clear canvas first
    canvas.clear();

    // Paint pixels — clamp to canvas bounds
    const max_x = @min(@as(usize, frame.width), canvas.pixel_count);
    const max_y = @min(@as(usize, frame.height), canvas.pixel_count);

    var y: usize = 0;
    while (y < max_y) : (y += 1) {
        var x: usize = 0;
        while (x < max_x) : (x += 1) {
            const palette_idx = frame.getPixel(x, y);
            const rgba = image.palette.getColor(palette_idx);
            if (rgba.a == 0) continue;
            canvas.pixels[y * canvas.pixel_count + x].color = Color.initRgba(
                rgba.r,
                rgba.g,
                rgba.b,
                rgba.a,
            );
        }
    }

    log.info(.application, "Loaded {s} ({d}x{d}, {d} colors)", .{
        zxl_path, frame.width, frame.height, image.palette.count,
    });
}

pub fn screenToCanvas(
    self: *const Canvas,
    screen_x: i32,
    screen_y: i32,
) ?struct { x: usize, y: usize } {
    if (screen_x < 0 or screen_y < 0) return null;

    const ux: usize = @intCast(screen_x);
    const uy: usize = @intCast(screen_y);

    if (ux < self.x_offset or uy < self.y_offset) return null;
    const canvas_x = (ux - self.x_offset) / self.pixel_size;
    const canvas_y = (uy - self.y_offset) / self.pixel_size;

    if (canvas_x >= self.pixel_count or canvas_y >= self.pixel_count) return null;
    return .{ .x = canvas_x, .y = canvas_y };
}
