const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const fd = @import("font_data.zig");
const FilteredGlyph = fd.FilteredGlyph;
const V2 = fd.V2;
const EarClipper = @import("ear_clipping.zig").EarClipper;

pub fn buildTriangles(
    allocator: Allocator,
    glyph: *const FilteredGlyph,
) ![][3]usize {
    if (glyph.total_points == 0 or glyph.contour_count == 0) {
        return &[_][3]usize{};
    }

    const contours = try allocator.alloc([]usize, glyph.contour_ends.len);
    defer {
        for (contours) |contour| {
            allocator.free(contour);
        }
        allocator.free(contours);
    }

    var start_idx: usize = 0;
    for (glyph.contour_ends, 0..) |contour_end, contour_num| {
        // contour_end is the inclusive last index of this contour
        const end_idx = contour_end + 1; // +1 to make it exclusive (one past the end)

        // Filter out duplicate consecutive vertices
        var filtered: ArrayList(usize) = .empty;
        defer filtered.deinit(allocator);

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

            try filtered.append(allocator, idx);
        }

        contours[contour_num] = try filtered.toOwnedSlice(allocator);
        start_idx = end_idx; // Next contour starts where this one ended
    }

    var clipper = EarClipper.init(allocator, glyph.points);
    defer clipper.deinit();

    return try clipper.triangulate(contours);
}
