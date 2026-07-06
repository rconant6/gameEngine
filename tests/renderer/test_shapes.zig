const std = @import("std");
const testing = std.testing;
const math = @import("math");
const V2 = math.V2;
const renderer = @import("renderer");
const Shapes = renderer.Shapes;
const WorldPoint = math.WorldPoint;
const Line = Shapes.Line(WorldPoint);
const Triangle = Shapes.Triangle(WorldPoint);
const Rectangle = Shapes.Rectangle(WorldPoint);
const Circle = Shapes.Circle(WorldPoint);
const Ellipse = Shapes.Ellipse(WorldPoint);

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

test "Shape: different shape types" {
    // Test for the Shape union type
    // Would test creation and switching between different shape variants
}
