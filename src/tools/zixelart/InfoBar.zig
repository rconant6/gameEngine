const std = @import("std");
const Self = @This();
const rend = @import("renderer");
const Colors = rend.Colors;
const Color = rend.Color;
const Renderer = rend.Renderer;
const RenderContext = rend.RenderContext;
const ShapeData = rend.ShapeData;
const ScreenPoint = rend.ScreenPoint;
const assets = @import("assets");
const Font = assets.Font;
const layout = @import("Layout.zig");
const Region = layout.Region;
const ZixelState = @import("ZixelState.zig");

region: Region,
shape: ShapeData,
state: *const ZixelState,

pub fn init(zixel_state: *const ZixelState) Self {
    const ScreenRect = rend.ShapeRegistry.getShapeType("RectangleScreen") orelse unreachable;
    return .{
        .state = zixel_state,
        .region = layout.info_bar,
        .shape = rend.ShapeRegistry.createShapeUnion(
            ScreenRect,
            ScreenRect.initFromTopLeft(
                .{ .x = layout.info_bar.x, .y = layout.info_bar.y },
                layout.info_bar.width,
                layout.info_bar.height,
            ),
        ),
    };
}

pub fn render(
    self: *const Self,
    renderer: *Renderer,
    font: *const Font,
    state: *const ZixelState,
    ctx: RenderContext,
) void {
    var buf: [256]u8 = undefined;
    // Background bar
    renderer.drawGeometry(
        self.shape,
        null,
        Colors.CHARCOAL,
        null,
        1.0,
        ctx,
    );

    const text_y = self.region.y + self.region.height / 2 - 2;
    const text_scale: f32 = 24.0;

    // Tool indicator (left side)
    renderer.drawTextScreen(
        font,
        std.ascii.lowerString(&buf, @tagName(state.active_tool)),
        .{ .x = 10, .y = text_y },
        text_scale,
        Colors.UI_BUTTON_TEXT,
        ctx,
    );

    // Active color indicator (center-left) - show color name if available
    renderer.drawTextScreen(
        font,
        std.ascii.lowerString(&buf, state.active_color_name),
        .{ .x = 150, .y = text_y },
        text_scale,
        Colors.UI_BUTTON_TEXT,
        ctx,
    );

    // Draw a small color swatch
    const swatch_size: f32 = 20;
    const swatch_x: f32 = 280;
    const swatch_y: f32 = self.region.y;
    const ScreenRect = rend.ShapeRegistry.getShapeType("RectangleScreen") orelse unreachable;
    const swatch = rend.ShapeRegistry.createShapeUnion(
        ScreenRect,
        ScreenRect.initFromTopLeft(
            .{ .x = swatch_x, .y = swatch_y },
            swatch_size,
            swatch_size,
        ),
    );
    renderer.drawGeometry(swatch, null, state.active_color, Colors.WHITE, 1.0, ctx);

    // Canvas size (center)
    renderer.drawTextScreen(
        font,
        "64x64",
        .{ .x = 400, .y = text_y },
        text_scale,
        Colors.UI_TEXT_INFO,
        ctx,
    );

    // Zoom level (right side)
    renderer.drawTextScreen(
        font,
        "100%",
        .{ .x = 550, .y = text_y },
        text_scale,
        Colors.UI_BUTTON_NORMAL,
        ctx,
    );

    // Coordinates (far right) - placeholder
    const loc_text = std.fmt.bufPrint(
        &buf,
        "[{d:3}, {d:3}]",
        .{ state.cursor_x orelse 0, state.cursor_y orelse 0 },
    ) catch "";
    renderer.drawTextScreen(
        font,
        loc_text,
        .{ .x = 700, .y = text_y },
        text_scale,
        Colors.UI_BUTTON_NORMAL,
        ctx,
    );
}
