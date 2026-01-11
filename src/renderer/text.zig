const std = @import("std");
const asset = @import("asset");
pub const Font = asset.Font;
pub const glyph_builder = asset.glyph_builder;
const FilteredGlyph = asset.FilteredGlyph;
const rend = @import("renderer.zig");
const Renderer = rend.Renderer;
const GamePoint = rend.GamePoint;
const Color = rend.Color;
const core = @import("core");
const ShapeRegistry = core.ShapeRegistry;
const Shapes = core.Shapes;
const ShapeData = core.ShapeData;
const V2 = rend.V2;

pub fn drawText(
    renderer: *Renderer,
    font: *const Font,
    text: []const u8,
    position: GamePoint,
    scale: f32,
    color: Color,
) void {
    const f = @constCast(font);
    var x_pos = position.x;
    for (text) |char| {
        const ascii_val: u32 = @intCast(char);
        const glyph_index = font.char_to_glyph.get(ascii_val) orelse continue;
        if (f.glyph_shapes.get(glyph_index)) |glyph| {
            drawGlyph(
                renderer,
                f,
                glyph_index,
                &glyph,
                scale,
                .{ .x = x_pos, .y = position.y },
                color,
            ) catch {
                // Skip glyphs that fail to render
                continue;
            };
        }

        const advance_f: f32 = @floatFromInt(f.glyph_advance_width.items[glyph_index].advance_width);
        const em_f: f32 = @floatFromInt(f.units_per_em);
        x_pos += (advance_f / em_f) * scale;
    }
}

fn drawGlyph(
    renderer: *Renderer,
    font: *Font,
    glyph_index: u16,
    glyph: *const FilteredGlyph,
    scale: f32,
    pos: V2,
    color: Color,
) !void {
    const triangles = if (font.glyph_triangles.get(glyph_index)) |cached|
        cached
    else blk: {
        const tris = try glyph_builder.buildTriangles(font.alloc, glyph);
        try font.glyph_triangles.put(glyph_index, tris);
        break :blk tris;
    };

    for (triangles) |tri| {
        const p0 = glyph.points[tri[0]];
        const p1 = glyph.points[tri[1]];
        const p2 = glyph.points[tri[2]];

        const t0 = V2{ .x = p0.x * scale + pos.x, .y = p0.y * scale + pos.y };
        const t1 = V2{ .x = p1.x * scale + pos.x, .y = p1.y * scale + pos.y };
        const t2 = V2{ .x = p2.x * scale + pos.x, .y = p2.y * scale + pos.y };

        const triangle: Shapes.Triangle = .{ .v0 = t0, .v1 = t1, .v2 = t2 };
        renderer.drawGeometry(
            ShapeRegistry.createShapeUnion(Shapes.Triangle, triangle),
            .{},
            color,
            null,
            1.0,
        );
    }
}
