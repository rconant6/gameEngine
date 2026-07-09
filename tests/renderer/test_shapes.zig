const std = @import("std");
const testing = std.testing;
const math = @import("math");
const V2 = math.V2;
const renderer = @import("renderer");
const Shapes = renderer.Shapes;
const WorldPoint = math.WorldPoint;
const Line = Shapes.Line;
const Triangle = Shapes.Triangle;
const Rectangle = Shapes.Rectangle;
const Circle = Shapes.Circle;
const Ellipse = Shapes.Ellipse;
const RoundedRect = Shapes.RoundedRect;
const Capsule = Shapes.Capsule;
const Arc = Shapes.Arc;
const NGon = Shapes.NGon;
const Star = Shapes.Star;
const PolyLine = Shapes.PolyLine;

test "Line: init with start and end points" {
    const start = V2{ .x = 0, .y = 0 };
    const end = V2{ .x = 10, .y = 10 };

    const line: Line = .{ .start = start, .end = end };

    try testing.expectEqual(@as(f32, 0), line.start.x);
    try testing.expectEqual(@as(f32, 0), line.start.y);
    try testing.expectEqual(@as(f32, 10), line.end.x);
    try testing.expectEqual(@as(f32, 10), line.end.y);
}

test "Line: horizontal line" {
    const start = V2{ .x = 0, .y = 5 };
    const end = V2{ .x = 10, .y = 5 };

    const line: Line = .{ .start = start, .end = end };

    try testing.expectEqual(line.start.y, line.end.y);
}

test "Line: vertical line" {
    const start = V2{ .x = 5, .y = 0 };
    const end = V2{ .x = 5, .y = 10 };

    const line: Line = .{ .start = start, .end = end };

    try testing.expectEqual(line.start.x, line.end.x);
}

test "Rectangle: init from center" {
    const center = V2{ .x = 10, .y = 20 };
    const rect = Rectangle.initFromCenter(center, 40, 30);

    try testing.expectEqual(@as(f32, 10), rect.center.x);
    try testing.expectEqual(@as(f32, 20), rect.center.y);
    try testing.expectEqual(@as(f32, 20), rect.half_width);
    try testing.expectEqual(@as(f32, 15), rect.half_height);
}

test "Rectangle: init square" {
    const center = V2{ .x = 5, .y = 5 };
    const rect = Rectangle.initSquare(center, 10);

    try testing.expectEqual(@as(f32, 5), rect.center.x);
    try testing.expectEqual(@as(f32, 5), rect.center.y);
    try testing.expectEqual(rect.half_width, rect.half_height);
    try testing.expectEqual(@as(f32, 5), rect.half_width);
}

test "Rectangle: dimensions are consistent" {
    const center = V2{ .x = 0, .y = 0 };
    const rect = Rectangle.initFromCenter(center, 100, 60);

    // Half dimensions should be half of full dimensions
    try testing.expectEqual(@as(f32, 50), rect.half_width);
    try testing.expectEqual(@as(f32, 30), rect.half_height);
}

test "Triangle: init with three points" {
    const points = [_]V2{
        V2{ .x = 0, .y = 0 },
        V2{ .x = 10, .y = 0 },
        V2{ .x = 5, .y = 10 },
    };

    const tri = Triangle.init(&points);

    // Triangle should have 3 vertices
    // Note: vertices are sorted by Y then X
    try testing.expect(tri.v0.y <= tri.v1.y);
    try testing.expect(tri.v1.y <= tri.v2.y);
}

test "Triangle: vertices are sorted" {
    const points = [_]V2{
        V2{ .x = 5, .y = 10 }, // Top
        V2{ .x = 0, .y = 0 }, // Bottom-left
        V2{ .x = 10, .y = 0 }, // Bottom-right
    };

    const tri = Triangle.init(&points);

    // After sorting, lowest Y should be first
    try testing.expectEqual(@as(f32, 0), tri.v0.y);
    try testing.expectEqual(@as(f32, 10), tri.v2.y);
}

test "Circle: basic properties" {
    const circle: Circle = .{ .origin = .{ .x = 3, .y = -4 }, .radius = 7 };

    try testing.expectEqual(@as(f32, 3), circle.origin.x);
    try testing.expectEqual(@as(f32, -4), circle.origin.y);
    try testing.expectEqual(@as(f32, 7), circle.radius);
}

test "Ellipse: basic properties" {
    const ellipse: Ellipse = .{
        .origin = .{ .x = 1, .y = 2 },
        .semi_major = 10,
        .semi_minor = 4,
    };

    try testing.expectEqual(@as(f32, 1), ellipse.origin.x);
    try testing.expectEqual(@as(f32, 2), ellipse.origin.y);
    try testing.expectEqual(@as(f32, 10), ellipse.semi_major);
    try testing.expectEqual(@as(f32, 4), ellipse.semi_minor);
}

// ============================================================
// Phase 3.1 shapes — struct/field coverage. Tessellation of
// these lives in test_tessellation.zig. RoundedRect is tested
// by literal (its init* helpers currently don't set `radius`).
// ============================================================

test "RoundedRect: basic properties" {
    const rr: RoundedRect = .{
        .center = .{ .x = 5, .y = -3 },
        .half_width = 10,
        .half_height = 4,
        .radius = 2,
    };

    try testing.expectEqual(@as(f32, 5), rr.center.x);
    try testing.expectEqual(@as(f32, -3), rr.center.y);
    try testing.expectEqual(@as(f32, 10), rr.half_width);
    try testing.expectEqual(@as(f32, 4), rr.half_height);
    try testing.expectEqual(@as(f32, 2), rr.radius);
}

test "RoundedRect: getWidth/getHeight are double the halves" {
    const rr: RoundedRect = .{
        .center = .{ .x = 0, .y = 0 },
        .half_width = 7,
        .half_height = 3,
        .radius = 1,
    };

    try testing.expectEqual(@as(f32, 14), rr.getWidth());
    try testing.expectEqual(@as(f32, 6), rr.getHeight());
}

test "Capsule: init halves the dimensions" {
    const cap = Capsule.init(.{ .x = 2, .y = 2 }, 20, 8);

    try testing.expectEqual(@as(f32, 2), cap.center.x);
    try testing.expectEqual(@as(f32, 10), cap.half_width);
    try testing.expectEqual(@as(f32, 4), cap.half_height);
}

test "Capsule: getWidth/getHeight round-trip init" {
    const cap = Capsule.init(.{ .x = 0, .y = 0 }, 30, 12);

    try testing.expectEqual(@as(f32, 30), cap.getWidth());
    try testing.expectEqual(@as(f32, 12), cap.getHeight());
}

test "Arc: basic properties (wedge, thickness 0)" {
    const arc: Arc = .{
        .origin = .{ .x = 1, .y = 1 },
        .radius = 5,
        .thickness = 0,
        .start_angle = 0,
        .end_angle = std.math.pi,
    };

    try testing.expectEqual(@as(f32, 5), arc.radius);
    try testing.expectEqual(@as(f32, 0), arc.thickness);
    try testing.expectEqual(@as(f32, 0), arc.start_angle);
    try testing.expectEqual(std.math.pi, arc.end_angle);
}

test "Arc: ring segment carries positive thickness" {
    const arc: Arc = .{
        .origin = .{ .x = 0, .y = 0 },
        .radius = 4,
        .thickness = 1.5,
        .start_angle = 0.5,
        .end_angle = 2.0,
    };

    // inner radius is derived at tess time; assert the inputs that drive it
    try testing.expectEqual(@as(f32, 4), arc.radius);
    try testing.expectEqual(@as(f32, 1.5), arc.thickness);
    try testing.expect(arc.radius - arc.thickness > 0); // ring not inverted
}

test "NGon: basic properties" {
    const ng: NGon = .{ .origin = .{ .x = 3, .y = 4 }, .radius = 2.5, .sides = 6 };

    try testing.expectEqual(@as(f32, 3), ng.origin.x);
    try testing.expectEqual(@as(f32, 2.5), ng.radius);
    try testing.expectEqual(@as(u32, 6), ng.sides);
}

test "Star: basic properties" {
    const st: Star = .{
        .origin = .{ .x = 0, .y = 0 },
        .outer_radius = 3,
        .inner_radius = 1.2,
        .points = 5,
    };

    try testing.expectEqual(@as(f32, 3), st.outer_radius);
    try testing.expectEqual(@as(f32, 1.2), st.inner_radius);
    try testing.expectEqual(@as(u32, 5), st.points);
    try testing.expect(st.inner_radius < st.outer_radius);
}

test "PolyLine: init dupes the points (owned, independent of source)" {
    const gpa = testing.allocator;
    var src = [_]V2{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 2 },
        .{ .x = 3, .y = -1 },
    };

    var pl = try PolyLine.init(gpa, &src);
    defer pl.deinit();

    // Same values...
    try testing.expectEqual(@as(usize, 3), pl.points.len);
    try testing.expectEqual(@as(f32, 1), pl.points[1].x);
    try testing.expectEqual(@as(f32, 2), pl.points[1].y);

    // ...but an independent copy: mutating the source must NOT touch the shape.
    src[1] = .{ .x = 99, .y = 99 };
    try testing.expectEqual(@as(f32, 1), pl.points[1].x);
    try testing.expectEqual(@as(f32, 2), pl.points[1].y);
}

test "Shape: different shape types" {
    // Covered by the per-shape struct tests above and by
    // test_tessellation.zig (union dispatch through tessellate()).
}
