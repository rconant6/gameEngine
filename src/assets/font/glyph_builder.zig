const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const fd = @import("font_data.zig");
const FilteredGlyph = fd.FilteredGlyph;
const V2 = fd.V2;
const EarClipper = @import("ear_clipping.zig").EarClipper;

pub fn buildTriangles(
    gpa: Allocator,
    glyph: *const FilteredGlyph,
) ![][3]usize {
    if (glyph.total_points == 0 or glyph.contour_count == 0) {
        return &[_][3]usize{};
    }

    const contours = try gpa.alloc([]usize, glyph.contour_ends.len);
    defer {
        for (contours) |contour| {
            gpa.free(contour);
        }
        gpa.free(contours);
    }

    var start_idx: usize = 0;
    for (glyph.contour_ends, 0..) |contour_end, contour_num| {
        // contour_end is the inclusive last index of this contour
        const end_idx = contour_end + 1; // +1 to make it exclusive (one past the end)

        // Filter out duplicate consecutive vertices
        var filtered: ArrayList(usize) = .empty;
        defer filtered.deinit(gpa);

        const epsilon = 0.00001; // Smaller epsilon to be more conservative

        // Build initial list, treating it as a circular buffer
        for (start_idx..end_idx) |idx| {
            const pt = glyph.points[idx];

            // Check against previous point (wrapping around to last point if we're at index 0)
            const prev_idx = if (idx > start_idx) idx - 1 else end_idx - 1;
            const prev_pt = glyph.points[prev_idx];

            const dx = pt.x - prev_pt.x;
            const dy = pt.y - prev_pt.y;
            if (dx * dx + dy * dy < epsilon * epsilon) continue;

            try filtered.append(gpa, idx);
        }

        // Remove collinear points - intermediate points on straight edges
        // that produce degenerate zero-area triangles and break ear clipping.
        // Use normalized cross product (sin of angle) so short edges at real
        // corners aren't falsely removed.
        const collinear_sin_eps = 0.01; // ~0.6 degrees
        var changed = true;
        while (changed) {
            changed = false;
            var i: usize = 0;
            while (i < filtered.items.len) {
                if (filtered.items.len < 3) break;

                const len = filtered.items.len;
                const prev = glyph.points[filtered.items[(i + len - 1) % len]];
                const curr = glyph.points[filtered.items[i]];
                const next = glyph.points[filtered.items[(i + 1) % len]];

                const e1x = curr.x - prev.x;
                const e1y = curr.y - prev.y;
                const e2x = next.x - curr.x;
                const e2y = next.y - curr.y;
                const cross = e1x * e2y - e1y * e2x;

                const len1_sq = e1x * e1x + e1y * e1y;
                const len2_sq = e2x * e2x + e2y * e2y;
                const len_product_sq = len1_sq * len2_sq;

                // If either edge has zero length, point is a duplicate — remove
                // Otherwise normalize: |sin(angle)| = |cross| / (|e1| * |e2|)
                const is_collinear = if (len_product_sq < 1e-12)
                    true
                else
                    (cross * cross) / len_product_sq < (collinear_sin_eps * collinear_sin_eps);

                if (is_collinear) {
                    _ = filtered.orderedRemove(i);
                    changed = true;
                } else {
                    i += 1;
                }
            }
        }

        contours[contour_num] = try filtered.toOwnedSlice(gpa);
        start_idx = end_idx; // Next contour starts where this one ended
    }

    var clipper = EarClipper.init(gpa, glyph.points);
    defer clipper.deinit();

    return try clipper.triangulate(contours);
}
