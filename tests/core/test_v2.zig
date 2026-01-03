const std = @import("std");
const testing = std.testing;
const V2 = @import("V2");

test "V2: creation and access" {
    const v = V2{ .x = 3.0, .y = 4.0 };
    try testing.expectEqual(@as(f32, 3.0), v.x);
    try testing.expectEqual(@as(f32, 4.0), v.y);
}

test "V2: ZERO constant" {
    try testing.expectEqual(@as(f32, 0.0), V2.ZERO.x);
    try testing.expectEqual(@as(f32, 0.0), V2.ZERO.y);
}

test "V2: add operation" {
    const a = V2{ .x = 1.0, .y = 2.0 };
    const b = V2{ .x = 3.0, .y = 4.0 };
    const result = a.add(b);
    try testing.expectEqual(@as(f32, 4.0), result.x);
    try testing.expectEqual(@as(f32, 6.0), result.y);
}

test "V2: add with negative values" {
    const a = V2{ .x = 5.0, .y = -3.0 };
    const b = V2{ .x = -2.0, .y = 7.0 };
    const result = a.add(b);
    try testing.expectEqual(@as(f32, 3.0), result.x);
    try testing.expectEqual(@as(f32, 4.0), result.y);
}

test "V2: sub operation" {
    const a = V2{ .x = 5.0, .y = 7.0 };
    const b = V2{ .x = 2.0, .y = 3.0 };
    const result = a.sub(b);
    try testing.expectEqual(@as(f32, 3.0), result.x);
    try testing.expectEqual(@as(f32, 4.0), result.y);
}

test "V2: sub resulting in negative" {
    const a = V2{ .x = 1.0, .y = 2.0 };
    const b = V2{ .x = 5.0, .y = 8.0 };
    const result = a.sub(b);
    try testing.expectEqual(@as(f32, -4.0), result.x);
    try testing.expectEqual(@as(f32, -6.0), result.y);
}

test "V2: mul by scalar" {
    const v = V2{ .x = 2.0, .y = 3.0 };
    const result = v.mul(3.0);
    try testing.expectEqual(@as(f32, 6.0), result.x);
    try testing.expectEqual(@as(f32, 9.0), result.y);
}

test "V2: mul by zero" {
    const v = V2{ .x = 2.0, .y = 3.0 };
    const result = v.mul(0.0);
    try testing.expectEqual(@as(f32, 0.0), result.x);
    try testing.expectEqual(@as(f32, 0.0), result.y);
}

test "V2: mul by negative" {
    const v = V2{ .x = 2.0, .y = -3.0 };
    const result = v.mul(-2.0);
    try testing.expectEqual(@as(f32, -4.0), result.x);
    try testing.expectEqual(@as(f32, 6.0), result.y);
}

test "V2: div by scalar" {
    const v = V2{ .x = 6.0, .y = 9.0 };
    const result = v.div(3.0);
    try testing.expectEqual(@as(f32, 2.0), result.x);
    try testing.expectEqual(@as(f32, 3.0), result.y);
}

test "V2: div by negative" {
    const v = V2{ .x = 6.0, .y = -9.0 };
    const result = v.div(-3.0);
    try testing.expectEqual(@as(f32, -2.0), result.x);
    try testing.expectEqual(@as(f32, 3.0), result.y);
}

test "V2: eql with equal vectors" {
    const a = V2{ .x = 1.0, .y = 2.0 };
    const b = V2{ .x = 1.0, .y = 2.0 };
    try testing.expect(a.eql(b));
}

test "V2: eql with nearly equal vectors (within epsilon)" {
    const a = V2{ .x = 1.0, .y = 2.0 };
    const b = V2{ .x = 1.000001, .y = 2.000001 };
    try testing.expect(a.eql(b));
}

test "V2: eql with different vectors" {
    const a = V2{ .x = 1.0, .y = 2.0 };
    const b = V2{ .x = 1.1, .y = 2.0 };
    try testing.expect(!a.eql(b));
}

test "V2: magnitude of unit vector" {
    const v = V2{ .x = 1.0, .y = 0.0 };
    const mag = v.magnitude();
    try testing.expectApproxEqAbs(@as(f32, 1.0), mag, 0.0001);
}

test "V2: magnitude of 3-4-5 triangle" {
    const v = V2{ .x = 3.0, .y = 4.0 };
    const mag = v.magnitude();
    try testing.expectApproxEqAbs(@as(f32, 5.0), mag, 0.0001);
}

test "V2: magnitude of zero vector" {
    const mag = V2.ZERO.magnitude();
    try testing.expectEqual(@as(f32, 0.0), mag);
}

test "V2: normalize unit vector" {
    const v = V2{ .x = 1.0, .y = 0.0 };
    const norm = v.normalize();
    try testing.expectApproxEqAbs(@as(f32, 1.0), norm.x, 0.0001);
    try testing.expectApproxEqAbs(@as(f32, 0.0), norm.y, 0.0001);
    try testing.expectApproxEqAbs(@as(f32, 1.0), norm.magnitude(), 0.0001);
}

test "V2: normalize arbitrary vector" {
    const v = V2{ .x = 3.0, .y = 4.0 };
    const norm = v.normalize();
    try testing.expectApproxEqAbs(@as(f32, 0.6), norm.x, 0.0001);
    try testing.expectApproxEqAbs(@as(f32, 0.8), norm.y, 0.0001);
    try testing.expectApproxEqAbs(@as(f32, 1.0), norm.magnitude(), 0.0001);
}

test "V2: distance between points" {
    const a = V2{ .x = 0.0, .y = 0.0 };
    const b = V2{ .x = 3.0, .y = 4.0 };
    const dist = a.distance(b);
    try testing.expectApproxEqAbs(@as(f32, 5.0), dist, 0.0001);
}

test "V2: distance is symmetric" {
    const a = V2{ .x = 1.0, .y = 2.0 };
    const b = V2{ .x = 4.0, .y = 6.0 };
    try testing.expectApproxEqAbs(a.distance(b), b.distance(a), 0.0001);
}

test "V2: distance to self is zero" {
    const v = V2{ .x = 5.0, .y = 7.0 };
    const dist = v.distance(v);
    try testing.expectEqual(@as(f32, 0.0), dist);
}

test "V2: dot product orthogonal vectors" {
    const a = V2{ .x = 1.0, .y = 0.0 };
    const b = V2{ .x = 0.0, .y = 1.0 };
    const result = a.dot(b);
    try testing.expectEqual(@as(f32, 0.0), result);
}

test "V2: dot product parallel vectors" {
    const a = V2{ .x = 2.0, .y = 0.0 };
    const b = V2{ .x = 3.0, .y = 0.0 };
    const result = a.dot(b);
    try testing.expectEqual(@as(f32, 6.0), result);
}

test "V2: dot product arbitrary vectors" {
    const a = V2{ .x = 1.0, .y = 2.0 };
    const b = V2{ .x = 3.0, .y = 4.0 };
    const result = a.dot(b);
    try testing.expectEqual(@as(f32, 11.0), result);
}

test "V2: dot product is commutative" {
    const a = V2{ .x = 2.0, .y = 3.0 };
    const b = V2{ .x = 5.0, .y = 7.0 };
    try testing.expectEqual(a.dot(b), b.dot(a));
}

test "V2: cross product parallel vectors" {
    const a = V2{ .x = 2.0, .y = 0.0 };
    const b = V2{ .x = 3.0, .y = 0.0 };
    const result = a.cross(b);
    try testing.expectEqual(@as(f32, 0.0), result);
}

test "V2: cross product perpendicular vectors" {
    const a = V2{ .x = 1.0, .y = 0.0 };
    const b = V2{ .x = 0.0, .y = 1.0 };
    const result = a.cross(b);
    try testing.expectEqual(@as(f32, 1.0), result);
}

test "V2: cross product arbitrary vectors" {
    const a = V2{ .x = 2.0, .y = 3.0 };
    const b = V2{ .x = 5.0, .y = 7.0 };
    const result = a.cross(b);
    try testing.expectEqual(@as(f32, -1.0), result);
}

test "V2: cross product is anti-commutative" {
    const a = V2{ .x = 2.0, .y = 3.0 };
    const b = V2{ .x = 5.0, .y = 7.0 };
    try testing.expectEqual(a.cross(b), -b.cross(a));
}

test "V2: chained operations" {
    const a = V2{ .x = 1.0, .y = 2.0 };
    const b = V2{ .x = 3.0, .y = 4.0 };
    const result = a.add(b).mul(2.0).sub(V2{ .x = 2.0, .y = 4.0 });
    try testing.expectEqual(@as(f32, 6.0), result.x);
    try testing.expectEqual(@as(f32, 8.0), result.y);
}
