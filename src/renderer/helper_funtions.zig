const Point = @import("core").V2;

pub fn sortPointByX(context: void, a: Point, b: Point) bool {
    _ = context;
    return a.x > b.x;
}

pub fn sortPointByY(context: void, a: Point, b: Point) bool {
    _ = context;
    return a.y > b.y;
}

pub fn sortPointByYThenX(context: void, a: Point, b: Point) bool {
    _ = context;
    if (a.y == b.y) {
        return a.x < b.x;
    }
    return a.y > b.y;
}

pub fn calculateCentroid(points: []const Point) Point {
    if (points.len == 0) return Point{ .x = 0, .y = 0 };

    var sum_x: f32 = 0;
    var sum_y: f32 = 0;

    for (points) |p| {
        sum_x += p.x;
        sum_y += p.y;
    }

    const flen: f32 = @floatFromInt(points.len);

    return Point{
        .x = sum_x / flen,
        .y = sum_y / flen,
    };
}
