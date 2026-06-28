//! Phase F5 — centered / right-anchored world-space text.
//!
//! Red-first. Targets API that does NOT exist yet:
//!   - ecs.TextAlign = enum { left, center, right }
//!   - Text.alignment: TextAlign = .left
//!   - Text.alignOffsetX(measured_width) f32  — the pure offset the renderer
//!     applies before drawing, so the draw math is testable without a Renderer.
//!
//! World-space [Text] is left-anchored from its Transform, so every title needs
//! a hand-tuned -x nudge. alignment lets the engine offset by the measured width:
//!   left   -> 0          (unchanged; the default)
//!   center -> -width/2   (text straddles the Transform x)
//!   right  -> -width     (text ends at the Transform x)
//!
//! These pin the pure math (no font / renderer). A companion test in the font
//! suite checks it composes with measureText against the real font.

const std = @import("std");
const testing = std.testing;

const ecs = @import("ecs");
const Text = ecs.Text;
const TextAlign = ecs.TextAlign;

const renderer = @import("renderer");
const Colors = renderer.Colors;

const assets = @import("assets");
const Font = assets.Font;

fn mkText(alignment: TextAlign) Text {
    return .{
        .text = "HELLO",
        .font_name = "__default__",
        .size = 1.0,
        .text_color = Colors.WHITE,
        .alignment = alignment,
    };
}

test "alignment defaults to left (existing Text unchanged)" {
    const t = Text{
        .text = "x",
        .font_name = "__default__",
        .size = 1.0,
        .text_color = Colors.WHITE,
    };
    try testing.expectEqual(TextAlign.left, t.alignment);
}

test "left alignment offsets nothing" {
    const t = mkText(.left);
    try testing.expectEqual(@as(f32, 0.0), t.alignOffsetX(12.0));
}

test "center alignment offsets by minus half the measured width" {
    const t = mkText(.center);
    try testing.expectApproxEqAbs(@as(f32, -6.0), t.alignOffsetX(12.0), 0.0001);
}

test "right alignment offsets by minus the full measured width" {
    const t = mkText(.right);
    try testing.expectApproxEqAbs(@as(f32, -12.0), t.alignOffsetX(12.0), 0.0001);
}

test "zero-width text offsets to zero regardless of alignment" {
    try testing.expectEqual(@as(f32, 0.0), mkText(.left).alignOffsetX(0.0));
    try testing.expectEqual(@as(f32, 0.0), mkText(.center).alignOffsetX(0.0));
    try testing.expectEqual(@as(f32, 0.0), mkText(.right).alignOffsetX(0.0));
}

// Integration: the offset composes with the real measureText the way RenderSys
// will use it — center offset == -measureText(text, size).x / 2.
test "center offset composes with measureText against the real font" {
    var font = try Font.initFromMemory(testing.allocator, assets.embedded_default_font);
    defer font.deinit();

    const t = mkText(.center); // text "HELLO", size 1.0
    const measured = font.measureText(t.text, t.size).x;
    try testing.expect(measured > 0);
    try testing.expectApproxEqAbs(-measured / 2.0, t.alignOffsetX(measured), 0.0001);
}
