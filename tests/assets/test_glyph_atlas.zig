const std = @import("std");
const testing = std.testing;
const assets = @import("assets");
const math = @import("math");

const Font = assets.Font;

// Load the embedded default font; its atlas is built during init.
fn loadFont() !Font {
    return Font.initFromMemory(testing.allocator, assets.embedded_default_font);
}

fn glyphIdFor(font: *Font, ch: u21) ?u16 {
    return font.char_to_glyph.get(@intCast(ch));
}

test "atlas has a non-empty backing bitmap sized w*h" {
    var font = try loadFont();
    defer font.deinit();

    const a = font.atlas;
    try testing.expect(a.w > 0);
    try testing.expect(a.h > 0);
    try testing.expectEqual(@as(usize, a.w) * a.h, a.pixels.len);
}

test "uvFor returns an entry for a common glyph ('A')" {
    var font = try loadFont();
    defer font.deinit();

    const gid = glyphIdFor(&font, 'A') orelse return error.SkipZigTest;
    const e = font.atlas.uvFor(gid) orelse return error.SkipZigTest;

    // uv rect within [0,1], and non-degenerate
    try testing.expect(e.u0 >= 0.0 and e.u0 <= 1.0);
    try testing.expect(e.v0 >= 0.0 and e.v0 <= 1.0);
    try testing.expect(e.u1 >= 0.0 and e.u1 <= 1.0);
    try testing.expect(e.v1 >= 0.0 and e.v1 <= 1.0);
    try testing.expect(e.u1 > e.u0);
    try testing.expect(e.v1 > e.v0);
}

test "uvFor advance is positive for a printable glyph" {
    var font = try loadFont();
    defer font.deinit();

    const gid = glyphIdFor(&font, 'm') orelse return error.SkipZigTest;
    const e = font.atlas.uvFor(gid) orelse return error.SkipZigTest;

    try testing.expect(e.advance > 0.0);
}

test "two distinct glyphs pack to distinct atlas rects" {
    var font = try loadFont();
    defer font.deinit();

    const ga = glyphIdFor(&font, 'A') orelse return error.SkipZigTest;
    const gb = glyphIdFor(&font, 'B') orelse return error.SkipZigTest;
    if (ga == gb) return error.SkipZigTest;

    const ea = font.atlas.uvFor(ga) orelse return error.SkipZigTest;
    const eb = font.atlas.uvFor(gb) orelse return error.SkipZigTest;

    // different glyphs must not occupy the exact same rect
    const same = ea.u0 == eb.u0 and ea.v0 == eb.v0 and ea.u1 == eb.u1 and ea.v1 == eb.v1;
    try testing.expect(!same);
}

test "uvFor is null for a glyph id that was never packed" {
    var font = try loadFont();
    defer font.deinit();

    // an id far past the font's glyph count should have no entry
    try testing.expect(font.atlas.uvFor(std.math.maxInt(u16)) == null);
}

test "measureText advances monotonically with length" {
    var font = try loadFont();
    defer font.deinit();

    const one = font.measureText("A", 32.0);
    const many = font.measureText("AAAA", 32.0);
    try testing.expect(many.x > one.x);
}

test "entry metrics: advance is em-normalized, size_px is pixel-scale" {
    var font = try loadFont();
    defer font.deinit();

    const gid = glyphIdFor(&font, 'M') orelse return error.SkipZigTest;
    const e = font.atlas.uvFor(gid) orelse return error.SkipZigTest;

    // advance/bearing are EM-NORMALIZED ([0,1] == one em); a printable glyph's
    // advance is a positive fraction of an em, comfortably under a few ems.
    try testing.expect(e.advance > 0.0 and e.advance < 3.0);
    // size_px is the rasterized cell, bounded by the atlas cell size
    const cell: f32 = @floatFromInt(assets.GlyphAtlas.CELL_PX + 2 * assets.GlyphAtlas.PAD);
    try testing.expect(e.size_px.x > 0.0 and e.size_px.x <= cell);
    try testing.expect(e.size_px.y > 0.0 and e.size_px.y <= cell);
}
