const std = @import("std");
const asset = @import("asset");
pub const Font = asset.Font;
const FilteredGlyph = asset.FilteredGlyph;
const rend = @import("renderer.zig");
const Renderer = rend.Renderer;
const GamePoint = rend.GamePoint;
const Color = rend.Color;
const ShapeData = rend.ShapeData;
const Line = rend.Line;
const Circle = rend.Circle;
const Rectangle = rend.Rectangle;
const Polygon = rend.Polygon;
const Ellipse = rend.Ellipse;
const V2 = rend.V2;

pub fn drawText(
    renderer: *Renderer,
    font: *const Font,
    text: []const u8,
    position: GamePoint,
    scale: f32,
    color: Color,
) void {
    var x_pos = position.x;
    for (text) |char| {
        const ascii_val: u32 = @intCast(char);
        const glyph_index = font.char_to_glyph.get(ascii_val) orelse continue;
        if (font.glyph_shapes.get(glyph_index)) |glyph| {
            drawGlyph(renderer, &glyph, scale, .{ .x = x_pos, .y = position.y }, color);
        }

        const advance_f: f32 = @floatFromInt(font.glyph_advance_width.items[glyph_index].advance_width);
        const em_f: f32 = @floatFromInt(font.units_per_em);
        x_pos += (advance_f / em_f) * scale;
    }
}

fn drawGlyph(
    renderer: *Renderer,
    glyph: *const FilteredGlyph,
    scale: f32,
    pos: V2,
    color: Color,
) void {
    var start_idx: usize = 0;
    for (glyph.contour_ends) |end_idx| {
        const contour_points = glyph.points[start_idx .. end_idx + 1];

        for (contour_points, 0..) |point, i| {
            const next_point = if (i == contour_points.len - 1)
                contour_points[0]
            else
                contour_points[i + 1];

            const p1 = V2{
                .x = point.x * scale + pos.x,
                .y = point.y * scale + pos.y,
            };
            const p2 = V2{
                .x = next_point.x * scale + pos.x,
                .y = next_point.y * scale + pos.y,
            };

            renderer.drawGeometry(
                .{ .line = .{ .start = p1, .end = p2 } },
                null,
                null,
                color,
                1,
            );
        }

        start_idx = end_idx + 1;
    }
}
