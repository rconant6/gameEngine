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
const assets = @import("assets");
const Font = assets.Font;

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
    var font = Font.initFromMemory(allocator, assets.embedded_default_font) catch |err| {
        log.err(.application, "Failed to load font: {any}", .{err});
        @panic("Cannot load font");
    };
    defer font.deinit();

    // const kb = plat.getKeyboard();
    // const mouse = plat.getMouse();
    log.debug(
        .application,
        "Number of Colors in library: {d}",
        .{ColorLibrary.getAllColors().len},
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

    // const palette = Palette.init();
    // palette.print();

    // const cs = ColorLibrary.getHueToneSat(.azure, .light, .vivid);
    // for (cs) |c| {
    //     log.debug(.application, "{s}", .{c.name});
    // }
    const color_name = "food_peach";
    const active_color = ColorLibrary.findByName(color_name) orelse blk: {
        log.err(.application, "Active Color was not found: {s}", .{color_name});
        break :blk TaggedColor.from(Colors.MAGENTA, color_name);
    };
    log.debug(.application, "Default Color: {s}", .{active_color.name});

    // const red = ColorLibrary.findByColor(Color.initRgba(255, 0, 0, 255));
    // log.debug(.application, "{any}", .{red});

    var state: ZixelState = .{
        .canvas = canvas,
        .active_color = active_color.color,
        .active_color_name = active_color.name,
        .active_tool = .pencil,
    };
    const info_bar: InfoBar = .init(&state);

    const ctx: rend.RenderContext = .{
        .camera_loc = .{ .x = 0, .y = 0 },
        .height = logical_height,
        .width = logical_width,
        .ortho_size = logical_height / 2,
    };

    // TODO: These checking functions need to be moved elsewhere!
    while (app.isRunning()) {
        try app.beginFrame();

        app.renderer.setClearColor(Colors.DARK_GRAY);
        app.renderer.clear();

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

        info_bar.render(&app.renderer, &font, &state, ctx);

        try app.endFrame();
    }
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
