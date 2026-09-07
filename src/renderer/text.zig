const asset = @import("assets");
pub const Font = asset.Font;
const GlyphEntry = asset.GlyphEntry;
const GlyphAtlas = asset.GlyphAtlas;
const rend = @import("renderer.zig");
const Renderer = rend.Renderer;
const Texture = Renderer.Texture;
const WorldPoint = rend.WorldPoint;
const ScreenPoint = rend.ScreenPoint;
const Color = rend.Color;
const ShapeRegistry = rend.ShapeRegistry;
const Shapes = rend.Shapes;
const V2 = rend.V2;
const log = @import("debug").log;

// All glyph metrics are EM-NORMALIZED ([0,1] == one em), matching glyph.points.
const cell: f32 = @floatFromInt(GlyphAtlas.CELL_PX);
const pad: f32 = @as(f32, @floatFromInt(GlyphAtlas.PAD)) / cell;

// Emit one glyph quad. Y-UP always — no space branch. The screen ClipMap is the
// only place that flips for screen space. `baseline_y` is the pen baseline in the
// target space. One textured Renderable per glyph → all share the atlas → coalesce.
fn emitGlyph(
    renderer: *Renderer,
    e: GlyphEntry,
    tex: *anyopaque,
    pen_x: f32,
    baseline_y: f32,
    scale: f32,
    color: Color,
    space: rend.CoordinateSpace,
    ctx: anytype,
) void {
    const wq = (e.size_px.x / cell) * scale; // cell size in em → space units
    const hq = (e.size_px.y / cell) * scale;

    // World is y-up, screen is y-down (opposite handedness — a real coordinate fact).
    // This is the SINGLE point where the two conventions meet: the glyph's visual "up"
    // is +y in world, -y on screen. dy = which way the glyph grows from the baseline.
    const dy: f32 = if (space == .world) 1.0 else -1.0;

    const left = pen_x + (-pad) * scale;
    const right = left + wq;
    const bottom = baseline_y - dy * pad * scale; // pad border below baseline
    const top = bottom + dy * hq; // visual top: up in world, down on screen

    const rect = Shapes.Rectangle{
        .center = .{ .x = (left + right) / 2, .y = (top + bottom) / 2 },
        .half_width = wq / 2,
        .half_height = hq / 2,
    };

    // uv follows getCorners order [BL, BR, TR, TL], which is by GEOMETRIC y (BL/BR =
    // low-y corners). Atlas is y-up (v0 = baseline, v1 = glyph top). In world the low-y
    // corners ARE the baseline (v0); on screen (dy=-1) the low-y corners are the glyph's
    // visual TOP, so the atlas rows map inverted → swap v0/v1 for the low/high pair.
    const v_lo = if (space == .world) e.v0 else e.v1; // uv for the low-y (BL/BR) corners
    const v_hi = if (space == .world) e.v1 else e.v0; // uv for the high-y (TR/TL) corners
    const uv: [4][2]f32 = .{
        .{ e.u0, v_lo }, // BL
        .{ e.u1, v_lo }, // BR
        .{ e.u1, v_hi }, // TR
        .{ e.u0, v_hi }, // TL
    };

    renderer.render(.{
        .shape = ShapeRegistry.createShapeUnion(Shapes.Rectangle, rect),
        .style = .{ .fill = color },
        .space = space,
        .texture = tex,
        .uv = uv,
        .sdf = true, // R8 coverage atlas → shader samples .r, masks fill by it
    }, ctx);
}

fn run(
    renderer: *Renderer,
    font: *const Font,
    tex: *Texture,
    text: []const u8,
    pen_x0: f32,
    baseline_y: f32,
    scale: f32,
    color: Color,
    space: rend.CoordinateSpace,
    ctx: anytype,
) void {
    var pen_x = pen_x0;
    for (text) |char| {
        const gid = font.char_to_glyph.get(@intCast(char)) orelse {
            log.err(.assets, "ASCII {d} not in font", .{char});
            continue;
        };
        if (font.atlas.uvFor(gid)) |e| {
            emitGlyph(
                renderer,
                e,
                tex,
                pen_x + e.bearing.x * scale,
                baseline_y,
                scale,
                color,
                space,
                ctx,
            );
            pen_x += e.advance * scale;
        } else {
            // no ink (space, etc.) — still advance by the glyph's advance if known
            if (font.char_to_glyph.get(@intCast(char))) |_| {
                // advance-only glyphs aren't in the atlas; fall back to a nominal space
                pen_x += 0.25 * scale;
            }
        }
    }
}

pub fn drawText(
    renderer: *Renderer,
    font: *const Font,
    tex: *Texture,
    text: []const u8,
    position: WorldPoint,
    scale: f32,
    color: Color,
    ctx: anytype,
) void {
    run(renderer, font, tex, text, position.x, position.y, scale, color, .world, ctx);
}

pub fn drawTextScreen(
    renderer: *Renderer,
    font: *const Font,
    tex: *Texture,
    text: []const u8,
    position: ScreenPoint,
    scale: f32,
    color: Color,
    ctx: anytype,
) void {
    run(renderer, font, tex, text, position.x, position.y, scale, color, .screen, ctx);
}
