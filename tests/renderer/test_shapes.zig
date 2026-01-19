const std = @import("std");
const testing = std.testing;
const math = @import("math");
const V2 = math.V2;
const renderer = @import("renderer");
const Shapes = renderer.Shapes;
const Line = Shapes.Line;
const Triangle = Shapes.Triangle;
const Rectangle = Shapes.Rectangle;
const Circle = Shapes.Circle;
const Ellipse = Shapes.Ellipse;

test "Line: init with start and end points" {
    const allocator = testing.allocator;
    const start = V2{ .x = 0, .y = 0 };
    const end = V2{ .x = 10, .y = 10 };

    const line = try Line.init(allocator, start, end);

    try testing.expectEqual(@as(f32, 0), line.start.x);
    try testing.expectEqual(@as(f32, 0), line.start.y);
    try testing.expectEqual(@as(f32, 10), line.end.x);
    try testing.expectEqual(@as(f32, 10), line.end.y);
}

test "Line: horizontal line" {
    const allocator = testing.allocator;
    const start = V2{ .x = 0, .y = 5 };
    const end = V2{ .x = 10, .y = 5 };

    const line = try Line.init(allocator, start, end);

    try testing.expectEqual(line.start.y, line.end.y);
}

test "Line: vertical line" {
    const allocator = testing.allocator;
    const start = V2{ .x = 5, .y = 0 };
    const end = V2{ .x = 5, .y = 10 };

    const line = try Line.init(allocator, start, end);

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
    const allocator = testing.allocator;
    const points = [_]V2{
        V2{ .x = 0, .y = 0 },
        V2{ .x = 10, .y = 0 },
        V2{ .x = 5, .y = 10 },
    };

    const tri = try Triangle.init(allocator, &points);

    // Triangle should have 3 vertices
    // Note: vertices are sorted by Y then X
    try testing.expect(tri.v0.y <= tri.v1.y);
    try testing.expect(tri.v1.y <= tri.v2.y);
}

test "Triangle: vertices are sorted" {
    const allocator = testing.allocator;
    const points = [_]V2{
        V2{ .x = 5, .y = 10 }, // Top
        V2{ .x = 0, .y = 0 },  // Bottom-left
        V2{ .x = 10, .y = 0 }, // Bottom-right
    };

    const tri = try Triangle.init(allocator, &points);

    // After sorting, lowest Y should be first
    try testing.expectEqual(@as(f32, 0), tri.v0.y);
    try testing.expectEqual(@as(f32, 10), tri.v2.y);
}

test "Circle: basic properties" {
    // Circle tests would depend on the Circle implementation
    // Placeholder for when Circle is defined in core_shapes
}

test "Ellipse: basic properties" {
    // Ellipse tests would depend on the Ellipse implementation
    // Placeholder for when Ellipse is defined in core_shapes
}

test "Shape: different shape types" {
    // Test for the Shape union type
    // Would test creation and switching between different shape variants
}
