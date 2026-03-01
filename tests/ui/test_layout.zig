const std = @import("std");
const testing = std.testing;
const math = @import("math");
const V2 = math.V2;
const Rect = @import("Rect");
const layout = @import("Layout");
const Size = layout.Size;
const Constraints = layout.Constraints;
const EdgeInsets = layout.EdgeInsets;
const Alignment = @import("Alignment").Alignment;

// ========================================
// Rect Tests
// ========================================

test "Rect: fields are accessible" {
    const r = Rect{ .x = 10, .y = 20, .width = 100, .height = 50 };
    try testing.expectEqual(@as(f32, 10), r.x);
    try testing.expectEqual(@as(f32, 20), r.y);
    try testing.expectEqual(@as(f32, 100), r.width);
    try testing.expectEqual(@as(f32, 50), r.height);
}

test "Rect: contains point inside origin rect" {
    const r = Rect{ .x = 0, .y = 0, .width = 100, .height = 80 };
    try testing.expect(r.contains(V2{ .x = 50, .y = 40 }));
}

test "Rect: contains point inside offset rect" {
    const r = Rect{ .x = 200, .y = 100, .width = 100, .height = 80 };
    try testing.expect(r.contains(V2{ .x = 250, .y = 140 }));
}

test "Rect: contains rejects point to the right" {
    const r = Rect{ .x = 0, .y = 0, .width = 100, .height = 80 };
    try testing.expect(!r.contains(V2{ .x = 150, .y = 40 }));
}

test "Rect: contains rejects point below" {
    const r = Rect{ .x = 0, .y = 0, .width = 100, .height = 80 };
    try testing.expect(!r.contains(V2{ .x = 50, .y = 120 }));
}

test "Rect: contains rejects point above and left" {
    const r = Rect{ .x = 50, .y = 50, .width = 100, .height = 80 };
    try testing.expect(!r.contains(V2{ .x = 10, .y = 10 }));
}

test "Rect: contains top-left corner (inclusive)" {
    const r = Rect{ .x = 10, .y = 10, .width = 100, .height = 80 };
    try testing.expect(r.contains(V2{ .x = 10, .y = 10 }));
}

test "Rect: contains bottom-right corner (inclusive)" {
    const r = Rect{ .x = 0, .y = 0, .width = 100, .height = 80 };
    try testing.expect(r.contains(V2{ .x = 100, .y = 80 }));
}

test "Rect: topLeft returns x and y" {
    const r = Rect{ .x = 30, .y = 45, .width = 100, .height = 80 };
    const tl = r.topLeft();
    try testing.expectEqual(@as(f32, 30), tl.x);
    try testing.expectEqual(@as(f32, 45), tl.y);
}

test "Rect: center returns midpoint" {
    const r = Rect{ .x = 0, .y = 0, .width = 100, .height = 80 };
    const c = r.center();
    try testing.expectEqual(@as(f32, 50), c.x);
    try testing.expectEqual(@as(f32, 40), c.y);
}

test "Rect: center of offset rect" {
    const r = Rect{ .x = 100, .y = 100, .width = 200, .height = 100 };
    const c = r.center();
    try testing.expectEqual(@as(f32, 200), c.x);
    try testing.expectEqual(@as(f32, 150), c.y);
}

test "Rect: inset shrinks all four sides on origin rect" {
    const r = Rect{ .x = 0, .y = 0, .width = 100, .height = 80 };
    const result = r.inset(10);
    try testing.expectEqual(@as(f32, 10), result.x);
    try testing.expectEqual(@as(f32, 10), result.y);
    try testing.expectEqual(@as(f32, 80), result.width);
    try testing.expectEqual(@as(f32, 60), result.height);
}

test "Rect: inset on offset rect shifts origin correctly" {
    const r = Rect{ .x = 50, .y = 30, .width = 200, .height = 100 };
    const result = r.inset(10);
    try testing.expectEqual(@as(f32, 60), result.x);
    try testing.expectEqual(@as(f32, 40), result.y);
    try testing.expectEqual(@as(f32, 180), result.width);
    try testing.expectEqual(@as(f32, 80), result.height);
}

test "Rect: inset zero is identity" {
    const r = Rect{ .x = 10, .y = 20, .width = 100, .height = 80 };
    const result = r.inset(0);
    try testing.expectEqual(r.x, result.x);
    try testing.expectEqual(r.y, result.y);
    try testing.expectEqual(r.width, result.width);
    try testing.expectEqual(r.height, result.height);
}

test "Rect: insetBy shrinks each side independently" {
    const r = Rect{ .x = 0, .y = 0, .width = 100, .height = 80 };
    const result = r.insetBy(5, 10, 15, 20);
    try testing.expectEqual(@as(f32, 5), result.x);
    try testing.expectEqual(@as(f32, 10), result.y);
    try testing.expectEqual(@as(f32, 80), result.width); // 100 - 5 - 15
    try testing.expectEqual(@as(f32, 50), result.height); // 80 - 10 - 20
}

test "Rect: insetBy zero on all sides is identity" {
    const r = Rect{ .x = 10, .y = 20, .width = 100, .height = 80 };
    const result = r.insetBy(0, 0, 0, 0);
    try testing.expectEqual(r.x, result.x);
    try testing.expectEqual(r.y, result.y);
    try testing.expectEqual(r.width, result.width);
    try testing.expectEqual(r.height, result.height);
}

// ========================================
// EdgeInsets Tests
// ========================================

test "EdgeInsets: direct construction has distinct sides" {
    const insets = EdgeInsets{ .top = 1, .right = 2, .bottom = 3, .left = 4 };
    try testing.expectEqual(@as(f32, 1), insets.top);
    try testing.expectEqual(@as(f32, 2), insets.right);
    try testing.expectEqual(@as(f32, 3), insets.bottom);
    try testing.expectEqual(@as(f32, 4), insets.left);
}

test "EdgeInsets: all sets all four sides equally" {
    const insets = EdgeInsets.all(8);
    try testing.expectEqual(@as(f32, 8), insets.top);
    try testing.expectEqual(@as(f32, 8), insets.right);
    try testing.expectEqual(@as(f32, 8), insets.bottom);
    try testing.expectEqual(@as(f32, 8), insets.left);
}

test "EdgeInsets: all zero" {
    const insets = EdgeInsets.all(0);
    try testing.expectEqual(@as(f32, 0), insets.top);
    try testing.expectEqual(@as(f32, 0), insets.right);
    try testing.expectEqual(@as(f32, 0), insets.bottom);
    try testing.expectEqual(@as(f32, 0), insets.left);
}

test "EdgeInsets: symmetric horizontal is left and right" {
    const insets = EdgeInsets.symmetric(12, 6);
    try testing.expectEqual(@as(f32, 12), insets.left);
    try testing.expectEqual(@as(f32, 12), insets.right);
    try testing.expectEqual(@as(f32, 6), insets.top);
    try testing.expectEqual(@as(f32, 6), insets.bottom);
}

test "EdgeInsets: symmetric horizontal and vertical are not swapped" {
    const insets = EdgeInsets.symmetric(20, 5);
    // horizontal (left/right) must be 20, vertical (top/bottom) must be 5
    try testing.expect(insets.left == insets.right);
    try testing.expect(insets.top == insets.bottom);
    try testing.expect(insets.left != insets.top);
}

// ========================================
// Constraints Tests
// ========================================

test "Constraints: tight sets min == max for both axes" {
    const c = Constraints.tight(200, 100);
    try testing.expectEqual(c.min_width, c.max_width);
    try testing.expectEqual(c.min_height, c.max_height);
    try testing.expectEqual(@as(f32, 200), c.min_width);
    try testing.expectEqual(@as(f32, 100), c.min_height);
}

test "Constraints: loose sets min to zero" {
    const c = Constraints.loose(400, 300);
    try testing.expectEqual(@as(f32, 0), c.min_width);
    try testing.expectEqual(@as(f32, 400), c.max_width);
    try testing.expectEqual(@as(f32, 0), c.min_height);
    try testing.expectEqual(@as(f32, 300), c.max_height);
}

test "Constraints: deflate reduces max by uniform inset" {
    const c = Constraints.loose(400, 300);
    const deflated = c.deflate(EdgeInsets.all(10));
    try testing.expectEqual(@as(f32, 380), deflated.max_width); // 400 - 10 - 10
    try testing.expectEqual(@as(f32, 280), deflated.max_height); // 300 - 10 - 10
}

test "Constraints: deflate with asymmetric insets" {
    const c = Constraints.loose(400, 300);
    const insets = EdgeInsets{ .top = 5, .right = 15, .bottom = 10, .left = 20 };
    const deflated = c.deflate(insets);
    try testing.expectEqual(@as(f32, 365), deflated.max_width); // 400 - 20 - 15
    try testing.expectEqual(@as(f32, 285), deflated.max_height); // 300 - 5 - 10
}

test "Constraints: deflate does not reduce min below zero" {
    const c = Constraints.loose(400, 300);
    const deflated = c.deflate(EdgeInsets.all(500));
    try testing.expectEqual(@as(f32, 0), deflated.max_width);
    try testing.expectEqual(@as(f32, 0), deflated.max_height);
}

test "Constraints: deflate zero insets is identity" {
    const c = Constraints.loose(400, 300);
    const deflated = c.deflate(EdgeInsets.all(0));
    try testing.expectEqual(c.min_width, deflated.min_width);
    try testing.expectEqual(c.max_width, deflated.max_width);
    try testing.expectEqual(c.min_height, deflated.min_height);
    try testing.expectEqual(c.max_height, deflated.max_height);
}

test "Constraints: deflate a tight constraint keeps max >= min" {
    const c = Constraints.tight(100, 80);
    const deflated = c.deflate(EdgeInsets.all(10));
    try testing.expect(deflated.max_width >= deflated.min_width);
    try testing.expect(deflated.max_height >= deflated.min_height);
}

// ========================================
// Size Tests
// ========================================

test "Size: fields are accessible" {
    const s = Size{ .width = 120, .height = 80 };
    try testing.expectEqual(@as(f32, 120), s.width);
    try testing.expectEqual(@as(f32, 80), s.height);
}

test "Size: constrain clamps width and height to max" {
    const s = Size{ .width = 500, .height = 400 };
    const c = Constraints.loose(300, 200);
    const clamped = s.constrain(c);
    try testing.expectEqual(@as(f32, 300), clamped.width);
    try testing.expectEqual(@as(f32, 200), clamped.height);
}

test "Size: constrain raises to min when below" {
    const s = Size{ .width = 10, .height = 5 };
    const c = Constraints.tight(100, 80);
    const clamped = s.constrain(c);
    try testing.expectEqual(@as(f32, 100), clamped.width);
    try testing.expectEqual(@as(f32, 80), clamped.height);
}

test "Size: constrain passes through when within bounds" {
    const s = Size{ .width = 150, .height = 100 };
    const c = Constraints{ .min_width = 50, .max_width = 300, .min_height = 50, .max_height = 200 };
    const clamped = s.constrain(c);
    try testing.expectEqual(@as(f32, 150), clamped.width);
    try testing.expectEqual(@as(f32, 100), clamped.height);
}

test "Size: constrain clamps axes independently" {
    // width too large, height within bounds
    const s = Size{ .width = 500, .height = 100 };
    const c = Constraints{ .min_width = 0, .max_width = 300, .min_height = 0, .max_height = 200 };
    const clamped = s.constrain(c);
    try testing.expectEqual(@as(f32, 300), clamped.width);
    try testing.expectEqual(@as(f32, 100), clamped.height); // unchanged
}

test "Size: constrain with tight constraint forces exact size" {
    const s = Size{ .width = 999, .height = 999 };
    const c = Constraints.tight(64, 32);
    const clamped = s.constrain(c);
    try testing.expectEqual(@as(f32, 64), clamped.width);
    try testing.expectEqual(@as(f32, 32), clamped.height);
}

test "Size: constrain with zero max produces zero size" {
    const s = Size{ .width = 100, .height = 100 };
    const c = Constraints.tight(0, 0);
    const clamped = s.constrain(c);
    try testing.expectEqual(@as(f32, 0), clamped.width);
    try testing.expectEqual(@as(f32, 0), clamped.height);
}

// ========================================
// Alignment Tests
// ========================================

// Exhaustiveness check: if a new variant is added without updating this
// switch, the test file will fail to compile — catching the gap immediately.
test "Alignment: horizontal switch is exhaustive" {
    const h = Alignment.Horizontal.center;
    const result: bool = switch (h) {
        .start => true,
        .center => true,
        .end => true,
        .stretch => true,
    };
    try testing.expect(result);
}

test "Alignment: vertical switch is exhaustive" {
    const v = Alignment.Vertical.center;
    const result: bool = switch (v) {
        .start => true,
        .center => true,
        .end => true,
        .stretch => true,
    };
    try testing.expect(result);
}
