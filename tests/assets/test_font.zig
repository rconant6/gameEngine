//! Integration tests for Font loading + measurement against the real embedded
//! Orbitron TTF. Exercises initFromMemory (the @embedFile path the editor and
//! tools use) and measureText invariants.

const std = @import("std");
const testing = std.testing;
const assets = @import("assets");
const Font = assets.Font;
const embedded = assets.embedded_default_font;

fn loadEmbedded() !Font {
    return Font.initFromMemory(testing.allocator, embedded);
}

test "initFromMemory parses the embedded font without leaking" {
    var font = try loadEmbedded();
    defer font.deinit();

    // a real TTF always declares a non-zero em square
    try testing.expect(font.units_per_em > 0);
    // Orbitron is upright Latin: ascender above baseline, descender below
    try testing.expect(font.ascender > 0);
    try testing.expect(font.descender < 0);
}

test "measureText: empty string has zero width" {
    var font = try loadEmbedded();
    defer font.deinit();

    const m = font.measureText("", 1.0);
    try testing.expectEqual(@as(f32, 0.0), m.x);
    // height is line-metric based, independent of content
    try testing.expect(m.y > 0.0);
}

test "measureText: width grows with more characters" {
    var font = try loadEmbedded();
    defer font.deinit();

    const one = font.measureText("A", 1.0).x;
    const three = font.measureText("AAA", 1.0).x;

    try testing.expect(one > 0.0);
    try testing.expect(three > one);
    // three identical glyphs should be ~3x one (same advance each)
    try testing.expectApproxEqRel(one * 3.0, three, 0.0001);
}

test "measureText: width and height scale linearly with scale" {
    var font = try loadEmbedded();
    defer font.deinit();

    const base = font.measureText("Hello", 1.0);
    const double = font.measureText("Hello", 2.0);

    try testing.expectApproxEqRel(base.x * 2.0, double.x, 0.0001);
    try testing.expectApproxEqRel(base.y * 2.0, double.y, 0.0001);
}

test "measureText: height is constant regardless of text" {
    var font = try loadEmbedded();
    defer font.deinit();

    const short = font.measureText("I", 1.0).y;
    const long = font.measureText("The quick brown fox", 1.0).y;
    try testing.expectApproxEqRel(short, long, 0.0001);
}

test "measureText: unknown glyphs are skipped, not counted" {
    var font = try loadEmbedded();
    defer font.deinit();

    // control characters (e.g. 0x00) have no cmap entry → skipped via `continue`
    const plain = font.measureText("AB", 1.0).x;
    const with_ctrl = font.measureText("A\x00B", 1.0).x;
    try testing.expectApproxEqRel(plain, with_ctrl, 0.0001);
}

// MARK: malformed input — errors, not crashes
//
// Exercises the graceful-degradation path: a structurally-valid header that's
// missing required tables must surface an error (so AssetManager can fall back
// to the default font) instead of crashing. This also drives the
// requireTable log.err in initFromData — that error log is expected here.
//
// NOTE: data shorter than a parse step (e.g. a truncated header) intentionally
// PANICS via FontReader's bounds checks rather than returning an error; that
// path is covered in test_font_reader.zig and can't be expectError'd.

test "initFromMemory: a valid header with no tables reports the missing table" {
    // FontDirHeader is 16 bytes (4-byte trailing padding). num_tables = 0, so
    // the directory parses but the first required table ('head') is absent.
    const data = [_]u8{
        0x00, 0x01, 0x00, 0x00, // sfnt_version 0x00010000
        0x00, 0x00, // num_tables = 0
        0x00, 0x00, // search_range
        0x00, 0x00, // entry_selector
        0x00, 0x00, // range_shift
        0x00, 0x00, 0x00, 0x00, // padding (consumed then rewound)
    };
    try testing.expectError(
        error.HeadTableNotFound,
        Font.initFromMemory(testing.allocator, &data),
    );
}
