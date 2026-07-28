//! Tessellation coverage — drives the REAL `renderer.tessellate` with a
//! capturing fake vertex, asserting:
//!   - vertex COUNT per shape/style (geometry topology), and
//!   - vertex COLOR (opacity applied at pack time — the private packWithOpacity
//!     path, observable through the u32 handed to makeVertex).
//!
//! These drive the real tessellator, not a stand-in. Each test asserts the
//! correct expected output for its shape.

const std = @import("std");
const testing = std.testing;
const rend = @import("renderer");
const tessellate = rend.tessellate;
const Batch = rend.Batch;
const ShapeData = rend.ShapeData;
const ShapeRegistry = rend.ShapeRegistry;
const Shapes = rend.Shapes;
const DrawStyle = rend.DrawStyle;
const Gradient = rend.Gradient;
const Color = rend.Color;
const math = @import("math");
const V2 = math.V2;

// ---- capturing fake backend vertex/key -------------------------------------

const TestVertex = struct {
    pos: [2]f32,
    uv: [2]f32,
    color: u32, // linear rgba packed RRGGBBAA (test-side storage for byte assertions)
};

// Pack the tessellator's linear [4]f32 color into RRGGBBAA bytes so the byte-level
// assertions below (channel extraction, exact match) keep working on the new seam.
fn packLinear(c: [4]f32) u32 {
    const b = struct {
        fn q(x: f32) u32 {
            return @intFromFloat(@round(std.math.clamp(x, 0, 1) * 255.0));
        }
    };
    return (b.q(c[0]) << 24) | (b.q(c[1]) << 16) | (b.q(c[2]) << 8) | b.q(c[3]);
}

fn makeTestVertex(pos: [2]f32, uv: [2]f32, color: [4]f32, xform_index: u16) TestVertex {
    _ = xform_index; // tests assert on pos/color only; transform is applied GPU-side
    return .{ .pos = pos, .uv = uv, .color = packLinear(color) };
}

// Single-primitive key; eql required by Batch.pushCall.
const TestKey = struct {
    id: u8 = 0,
    pub fn eql(self: TestKey, other: TestKey) bool {
        return self.id == other.id;
    }
};

const TestBatch = Batch(TestVertex, TestKey);

fn tessShape(batch: *TestBatch, shape_data: ShapeData, style: DrawStyle) !void {
    try tessellate(
        TestVertex,
        TestKey,
        batch,
        makeTestVertex,
        shape_data,
        null, // uv (untextured — shapes emit {0,0})
        0, // xform_index (identity slot; transform is applied GPU-side now)
        style,
        0.1, // hw (stroke half-width)
        50.0, // px_per_unit (drives bucketFor / segment count)
    );
}

fn shape(comptime T: type, value: T) ShapeData {
    return ShapeRegistry.createShapeUnion(T, value);
}

// Expected packed color after opacity is applied — matches the linear seam the
// tessellator now emits (linear rgb + alpha×opacity, packed the same as makeTestVertex).
fn expectedPacked(c: Color, opacity: f32) u32 {
    return packLinear(c.linearOpacity(opacity));
}

fn expectAllColor(batch: *const TestBatch, expected: u32) !void {
    try testing.expect(batch.vertices.items.len > 0);
    for (batch.vertices.items) |v| {
        try testing.expectEqual(expected, v.color);
    }
}

// ============================================================
// Geometry: vertex counts (implemented arms)
// ============================================================

test "NGon fill: fan dedups to w+1 verts, 3w indices" {
    var batch = TestBatch.init(testing.allocator);
    defer batch.deinit();

    const hex = shape(Shapes.NGon, .{ .origin = .{ .x = 0, .y = 0 }, .radius = 5, .sides = 6 });
    try tessShape(&batch, hex, .{ .fill = Color.initRgba(255, 0, 0, 255) });

    // fan: center + 6 rim = 7 unique verts; 6 tris = 18 indices
    try testing.expectEqual(@as(usize, 6 + 1), batch.vertices.items.len);
    try testing.expectEqual(@as(usize, 6 * 3), batch.indices.items.len);
}

test "Star fill: fan dedups to 2n+1 verts, 2n*3 indices" {
    var batch = TestBatch.init(testing.allocator);
    defer batch.deinit();

    const star = shape(Shapes.Star, .{
        .origin = .{ .x = 0, .y = 0 },
        .outer_radius = 4,
        .inner_radius = 1.5,
        .points = 5,
    });
    try tessShape(&batch, star, .{ .fill = Color.initRgba(0, 255, 0, 255) });

    // 2*5 rim + center = 11 verts; 10 tris = 30 indices
    try testing.expectEqual(@as(usize, 2 * 5 + 1), batch.vertices.items.len);
    try testing.expectEqual(@as(usize, 2 * 5 * 3), batch.indices.items.len);
}

test "PolyLine stroke: 4 verts + 6 indices per open segment" {
    var batch = TestBatch.init(testing.allocator);
    defer batch.deinit();

    var pts = [_]V2{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 2, .y = 0 },
        .{ .x = 3, .y = 1 },
    };
    var pl = try Shapes.PolyLine.init(testing.allocator, &pts);
    defer pl.deinit();

    try tessShape(&batch, shape(Shapes.PolyLine, pl), .{ .stroke = Color.initRgba(0, 0, 255, 255) });

    // 4 points → 3 open segments; each butt-join segment = 4 verts, 6 indices
    try testing.expectEqual(@as(usize, 3 * 4), batch.vertices.items.len);
    try testing.expectEqual(@as(usize, 3 * 6), batch.indices.items.len);
}

test "NGon fill+stroke: fan + strip verts, both index runs" {
    var batch = TestBatch.init(testing.allocator);
    defer batch.deinit();

    const sides: usize = 5;
    const pent = shape(Shapes.NGon, .{ .origin = .{ .x = 0, .y = 0 }, .radius = 3, .sides = @intCast(sides) });
    try tessShape(&batch, pent, .{
        .fill = Color.initRgba(255, 255, 0, 255),
        .stroke = Color.initRgba(255, 255, 255, 255),
    });

    // fill fan: sides+1 verts, sides*3 idx ; closed stroke: sides*4 verts, sides*6 idx
    try testing.expectEqual(@as(usize, (sides + 1) + sides * 4), batch.vertices.items.len);
    try testing.expectEqual(@as(usize, sides * 3 + sides * 6), batch.indices.items.len);
}

test "Rectangle fill: 4 verts, 6 indices (quad)" {
    var batch = TestBatch.init(testing.allocator);
    defer batch.deinit();

    const rect = shape(Shapes.Rectangle, Shapes.Rectangle.initFromCenter(.{ .x = 0, .y = 0 }, 4, 2));
    try tessShape(&batch, rect, .{ .fill = Color.initRgba(10, 20, 30, 255) });

    try testing.expectEqual(@as(usize, 4), batch.vertices.items.len);
    try testing.expectEqual(@as(usize, 6), batch.indices.items.len);
}

test "no-style shape emits nothing" {
    var batch = TestBatch.init(testing.allocator);
    defer batch.deinit();

    const circ = shape(Shapes.Circle, .{ .origin = .{ .x = 0, .y = 0 }, .radius = 2 });
    try tessShape(&batch, circ, .{});

    try testing.expectEqual(@as(usize, 0), batch.vertices.items.len);
}

// ============================================================
// Opacity: color applied at pack time (real packWithOpacity path)
// ============================================================

test "opacity 1.0 leaves fill alpha untouched (fast path)" {
    var batch = TestBatch.init(testing.allocator);
    defer batch.deinit();

    const tri = shape(Shapes.Triangle, Shapes.Triangle.init(&.{
        .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = 0, .y = 1 },
    }));
    const fill = Color.initRgba(200, 100, 50, 200);
    try tessShape(&batch, tri, .{ .fill = fill, .opacity = 1.0 });

    try expectAllColor(&batch, expectedPacked(fill, 1.0));
}

test "opacity 0.5 halves the fill alpha, RGB unchanged" {
    var batch = TestBatch.init(testing.allocator);
    defer batch.deinit();

    const tri = shape(Shapes.Triangle, Shapes.Triangle.init(&.{
        .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = 0, .y = 1 },
    }));
    const fill = Color.initRgba(200, 100, 50, 255);
    try tessShape(&batch, tri, .{ .fill = fill, .opacity = 0.5 });

    try expectAllColor(&batch, expectedPacked(fill, 0.5));
    // guard against a no-op impl: must differ from the opaque pack
    try testing.expect(expectedPacked(fill, 0.5) != fill.pack());
}

test "opacity multiplies an already-translucent color (stacking)" {
    var batch = TestBatch.init(testing.allocator);
    defer batch.deinit();

    const tri = shape(Shapes.Triangle, Shapes.Triangle.init(&.{
        .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = 0, .y = 1 },
    }));
    const fill = Color.initRgba(255, 255, 255, 128); // authored 50% → *0.5 ≈ 64
    try tessShape(&batch, tri, .{ .fill = fill, .opacity = 0.5 });

    try expectAllColor(&batch, expectedPacked(fill, 0.5));
}

test "opacity applies to stroke color too" {
    var batch = TestBatch.init(testing.allocator);
    defer batch.deinit();

    const hex = shape(Shapes.NGon, .{ .origin = .{ .x = 0, .y = 0 }, .radius = 3, .sides = 6 });
    const stroke = Color.initRgba(255, 255, 255, 255);
    try tessShape(&batch, hex, .{ .stroke = stroke, .opacity = 0.5 });

    try expectAllColor(&batch, expectedPacked(stroke, 0.5));
}

// ============================================================
// These assert the correct expected output; a shape whose tess isn't
// implemented fails here, which is the signal.
// ============================================================

test "Arc wedge (thickness 0) fill emits a fan" {
    var batch = TestBatch.init(testing.allocator);
    defer batch.deinit();

    const arc = shape(Shapes.Arc, .{
        .origin = .{ .x = 0, .y = 0 },
        .radius = 5,
        .thickness = 0,
        .start_angle = 0,
        .end_angle = std.math.pi, // half sweep
    });
    try tessShape(&batch, arc, .{ .fill = Color.initRgba(255, 200, 0, 255) });

    // a filled wedge must emit triangles; exact count depends on segment choice,
    // but it must be a positive multiple of 3 and non-empty.
    try testing.expect(batch.vertices.items.len > 0);
    // topology lives in the index buffer now; it must be whole triangles
    try testing.expectEqual(@as(usize, 0), batch.indices.items.len % 3);
}

test "Capsule fill emits geometry" {
    var batch = TestBatch.init(testing.allocator);
    defer batch.deinit();

    const cap = shape(Shapes.Capsule, Shapes.Capsule.init(.{ .x = 0, .y = 0 }, 8, 3));
    try tessShape(&batch, cap, .{ .fill = Color.initRgba(0, 200, 120, 255) });

    try testing.expect(batch.vertices.items.len > 0);
    // topology lives in the index buffer now; it must be whole triangles
    try testing.expectEqual(@as(usize, 0), batch.indices.items.len % 3);
}

test "RoundedRect fill emits geometry" {
    var batch = TestBatch.init(testing.allocator);
    defer batch.deinit();

    const rr = shape(Shapes.RoundedRect, Shapes.RoundedRect.initFromCenter(.{ .x = 0, .y = 0 }, 6, 4, 1));
    try tessShape(&batch, rr, .{ .fill = Color.initRgba(60, 130, 255, 255) });

    try testing.expect(batch.vertices.items.len > 0);
    // topology lives in the index buffer now; it must be whole triangles
    try testing.expectEqual(@as(usize, 0), batch.indices.items.len % 3);
}

// ============================================================
// Gradients — evaluated per-vertex in local space (identity xf/map here, so
// vertex world coords == shape-local coords). Radial fans put the center vertex
// at distance 0 (t=0 → start_color) and perimeter at ~radius (t≈1 → end_color).
// ============================================================

fn hasColor(batch: *const TestBatch, expected: u32) bool {
    for (batch.vertices.items) |v| {
        if (v.color == expected) return true;
    }
    return false;
}

test "radial gradient: fan hub is start_color, perimeter reaches end_color" {
    var batch = TestBatch.init(testing.allocator);
    defer batch.deinit();

    const start = Color.initRgba(255, 255, 0, 255); // yellow
    const end = Color.initRgba(255, 0, 0, 255); // red
    const circ = shape(Shapes.Circle, .{ .origin = .{ .x = 0, .y = 0 }, .radius = 5 });
    try tessShape(&batch, circ, .{
        .fill = start,
        .gradient = .{ .kind = .radial, .start_color = start, .end_color = end },
    });

    // the fan hub (origin, distance 0 → t=0) is emitted as start_color, exactly.
    try testing.expect(hasColor(&batch, expectedPacked(start, 1.0)));
    // perimeter vertices (~radius → t near 1) reach end_color.
    try testing.expect(hasColor(&batch, expectedPacked(end, 1.0)));
}

test "gradient-only (no explicit fill) still renders" {
    var batch = TestBatch.init(testing.allocator);
    defer batch.deinit();

    const start = Color.initRgba(0, 255, 255, 255);
    const end = Color.initRgba(255, 0, 255, 255);
    const circ = shape(Shapes.Circle, .{ .origin = .{ .x = 0, .y = 0 }, .radius = 4 });
    // NOTE: no .fill set — only .gradient. Must still emit (fillColor() fallback).
    try tessShape(&batch, circ, .{
        .gradient = .{ .kind = .radial, .start_color = start, .end_color = end },
    });

    try testing.expect(batch.vertices.items.len > 0);
    try testing.expect(hasColor(&batch, expectedPacked(start, 1.0))); // hub = start
}

test "flat fill unaffected by absent gradient (fast path intact)" {
    var batch = TestBatch.init(testing.allocator);
    defer batch.deinit();

    const fill = Color.initRgba(10, 20, 30, 255);
    const circ = shape(Shapes.Circle, .{ .origin = .{ .x = 0, .y = 0 }, .radius = 3 });
    try tessShape(&batch, circ, .{ .fill = fill }); // no gradient

    // every vertex is the one flat packed color
    try expectAllColor(&batch, expectedPacked(fill, 1.0));
}

test "radial gradient produces MORE than 2 distinct colors (actually lerps)" {
    var batch = TestBatch.init(testing.allocator);
    defer batch.deinit();

    const start = Color.initRgba(0, 0, 0, 255);
    const end = Color.initRgba(255, 255, 255, 255);
    // ellipse: fan interior points land at varying radii → intermediate t values
    const ell = shape(Shapes.Ellipse, .{ .origin = .{ .x = 0, .y = 0 }, .semi_minor = 2, .semi_major = 6 });
    try tessShape(&batch, ell, .{
        .fill = start,
        .gradient = .{ .kind = .radial, .start_color = start, .end_color = end },
    });

    // count distinct colors — a real gradient yields several, a broken/flat one yields 1-2
    var seen: [64]u32 = undefined;
    var n: usize = 0;
    for (batch.vertices.items) |v| {
        var found = false;
        for (seen[0..n]) |s| if (s == v.color) {
            found = true;
            break;
        };
        if (!found and n < seen.len) {
            seen[n] = v.color;
            n += 1;
        }
    }
    try testing.expect(n >= 3);
}

test "linear gradient varies along its axis (directional)" {
    var batch = TestBatch.init(testing.allocator);
    defer batch.deinit();

    // start = cyan (R=0), end = magenta (R=255). Along +x, red should INCREASE.
    // (The extent uses the shape's bounding radius, so corners land at
    // intermediate t rather than pure 0/1 — we test the DIRECTION, not exact
    // endpoints: left-side vertices are more cyan, right-side more magenta.)
    const start = Color.initRgba(0, 255, 255, 255);
    const end = Color.initRgba(255, 0, 255, 255);
    const rect = shape(Shapes.Rectangle, Shapes.Rectangle.initFromCenter(.{ .x = 0, .y = 0 }, 10, 6));
    try tessShape(&batch, rect, .{
        .fill = start,
        .gradient = .{ .kind = .linear, .start_color = start, .end_color = end, .angle = 0 },
    });

    // find the red channel of the left-most and right-most emitted vertices
    var left_r: u32 = 999;
    var right_r: u32 = 999;
    var min_x: f32 = std.math.inf(f32);
    var max_x: f32 = -std.math.inf(f32);
    for (batch.vertices.items) |v| {
        const r = (v.color >> 24) & 0xFF;
        if (v.pos[0] < min_x) {
            min_x = v.pos[0];
            left_r = r;
        }
        if (v.pos[0] > max_x) {
            max_x = v.pos[0];
            right_r = r;
        }
    }
    // red rises left→right (cyan→magenta along +x): proves linear directionality
    try testing.expect(right_r > left_r);
}

test "gradient endpoints honor opacity" {
    var batch = TestBatch.init(testing.allocator);
    defer batch.deinit();

    const start = Color.initRgba(255, 255, 255, 255);
    const end = Color.initRgba(255, 0, 0, 255);
    const circ = shape(Shapes.Circle, .{ .origin = .{ .x = 0, .y = 0 }, .radius = 5 });
    try tessShape(&batch, circ, .{
        .fill = start,
        .opacity = 0.5,
        .gradient = .{ .kind = .radial, .start_color = start, .end_color = end },
    });

    // hub = start with alpha halved (opacity applied before pack, same as flat)
    try testing.expect(hasColor(&batch, expectedPacked(start, 0.5)));
}
