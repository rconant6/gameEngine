const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Point = @import("font_data.zig").V2;

const Contour = []const usize;
const Triangle = [3]usize;

const log = @import("debug").log;

const VertexClass = enum { convex, reflex };

pub const EarClipper = struct {
    gpa: Allocator,
    vertices: []const Point,

    polygon: ArrayList(usize), // active vertex indices — shrinks as ears are clipped
    reflex: ArrayList(VertexClass), // per-vertex classification, 1:1 with polygon
    triangles: ArrayList(Triangle), // output accumulator
    winding_sign: f32 = -1.0, // -1 = CW, +1 = CCW

    pub fn init(gpa: Allocator, vertices: []const Point) EarClipper {
        return .{
            .gpa = gpa,
            .vertices = vertices,
            .polygon = .empty,
            .reflex = .empty,
            .triangles = .empty,
        };
    }

    pub fn deinit(self: *EarClipper) void {
        self.polygon.deinit(self.gpa);
        self.reflex.deinit(self.gpa);
        self.triangles.deinit(self.gpa);
    }

    /// Triangulate one or more contours. The first CW contour is the outer
    /// boundary; any CCW contours are holes that get merged in via bridge edges.
    pub fn triangulate(self: *EarClipper, contours: []const Contour) ![]Triangle {
        var outers: ArrayList(Contour) = .empty;
        defer outers.deinit(self.gpa);
        var holes: ArrayList(Contour) = .empty;
        defer holes.deinit(self.gpa);

        for (contours) |contour| {
            const area = signedArea(self.vertices, contour);

            if (@abs(area) < 0.000001) {
                log.warn(.assets, "Skipping degenerate contour (area={d:.8})", .{area});
                continue;
            } else if (area < 0) {
                try outers.append(self.gpa, contour);
            } else {
                try holes.append(self.gpa, contour);
            }
        }

        if (outers.items.len == 0) return error.NoOuterContour;

        for (outers.items) |outer| {
            // Assign holes to this outer if they lie inside it
            var matched_holes: ArrayList(Contour) = .empty;
            defer matched_holes.deinit(self.gpa);

            for (holes.items) |hole| {
                // Test whether the hole's first vertex is inside this outer contour
                if (hole.len > 0 and pointInContour(self.vertices, outer, self.vertices[hole[0]])) {
                    try matched_holes.append(self.gpa, hole);
                }
            }

            const merged = try self.eliminateHoles(outer, matched_holes.items);
            defer self.gpa.free(merged);

            self.polygon.clearRetainingCapacity();
            self.reflex.clearRetainingCapacity();

            try self.polygon.appendSlice(self.gpa, merged);
            try self.clipEars();
        }

        return self.triangles.toOwnedSlice(self.gpa);
    }

    // ── Core ear-clipping loop ──────────────────────────────────────────

    fn clipEars(self: *EarClipper) !void {
        if (self.polygon.items.len < 3) return error.ToFewVerticesToClip;

        // Determine winding from signed area
        self.winding_sign = if (signedArea(self.vertices, self.polygon.items) < 0) @as(f32, -1.0) else @as(f32, 1.0);

        try self.reflex.ensureTotalCapacity(self.gpa, self.polygon.items.len);
        for (0..self.polygon.items.len) |i| {
            self.reflex.appendAssumeCapacity(self.classifyVertex(i));
        }

        while (self.polygon.items.len > 3) {
            const remaining_area = signedArea(self.vertices, self.polygon.items);
            if (@abs(remaining_area) < 0.000001) {
                log.warn(.assets, "Remaining polygon degenerate (area={d:.8}), stopping early", .{remaining_area});
                return;
            }

            // Find an ear
            var ear_idx: ?usize = null;
            for (0..self.polygon.items.len) |i| {
                if (self.isEar(i)) {
                    ear_idx = i;
                    break;
                }
            }

            const ear = ear_idx orelse {
                // Concave shapes (e.g. 'H') can leave a remainder whose winding
                // is opposite the original. Detect and adapt once.
                const new_sign: f32 = if (remaining_area < 0) -1.0 else 1.0;
                if (new_sign != self.winding_sign) {
                    self.winding_sign = new_sign;
                    for (0..self.polygon.items.len) |ri| {
                        self.reflex.items[ri] = self.classifyVertex(ri);
                    }
                    continue;
                }
                return error.NoEarFound;
            };

            // Emit triangle and remove ear vertex
            const p_len = self.polygon.items.len;
            const prev_idx = (ear + p_len - 1) % p_len;
            const next_idx = (ear + 1) % p_len;

            try self.triangles.append(self.gpa, .{
                self.polygon.items[prev_idx],
                self.polygon.items[ear],
                self.polygon.items[next_idx],
            });

            _ = self.polygon.orderedRemove(ear);
            _ = self.reflex.orderedRemove(ear);

            // Reclassify the two neighbors whose adjacency changed
            const new_len = self.polygon.items.len;
            if (new_len > 0) {
                const new_prev = if (ear > 0) ear - 1 else new_len - 1;
                const new_next = if (ear < new_len) ear else 0;
                self.reflex.items[new_prev] = self.classifyVertex(new_prev);
                self.reflex.items[new_next] = self.classifyVertex(new_next);
            }
        }

        // Emit the final triangle
        try self.triangles.append(self.gpa, .{
            self.polygon.items[0],
            self.polygon.items[1],
            self.polygon.items[2],
        });
    }

    // ── Geometry helpers ────────────────────────────────────────────────

    /// Convexity depends on winding direction. Multiplying the cross product
    /// by winding_sign normalises both cases: the result is positive for
    /// convex vertices regardless of CW/CCW.
    fn isConvex(a: Point, b: Point, c: Point, winding_sign: f32) bool {
        const edge1 = b.sub(a);
        const edge2 = c.sub(b);
        const cross = edge1.x * edge2.y - edge1.y * edge2.x;
        return cross * winding_sign >= -0.00001;
    }

    /// Inclusive boundary test — points ON an edge count as inside so that
    /// reflex vertices sharing an edge with a candidate ear block it,
    /// preventing overlapping triangles in concave shapes.
    fn pointInTriangle(p: Point, a: Point, b: Point, c: Point) bool {
        const v0: Point = .{ .x = c.x - a.x, .y = c.y - a.y };
        const v1: Point = .{ .x = b.x - a.x, .y = b.y - a.y };
        const v2: Point = .{ .x = p.x - a.x, .y = p.y - a.y };

        const d00 = v0.dot(v0);
        const d01 = v0.dot(v1);
        const d11 = v1.dot(v1);
        const d20 = v2.dot(v0);
        const d21 = v2.dot(v1);

        const denom = d00 * d11 - d01 * d01;
        if (@abs(denom) < 1e-10) return false;

        const inv_denom = 1.0 / denom;
        const u = (d11 * d20 - d01 * d21) * inv_denom;
        const v = (d00 * d21 - d01 * d20) * inv_denom;

        const eps = -0.00001;
        return (u >= eps) and (v >= eps) and (u + v <= 1.0 - eps);
    }

    /// Ray-casting point-in-polygon test. Returns true if p is inside the contour.
    fn pointInContour(vertices: []const Point, contour: Contour, p: Point) bool {
        var inside = false;
        const n = contour.len;
        var j: usize = n - 1;
        for (0..n) |i| {
            const vi = vertices[contour[i]];
            const vj = vertices[contour[j]];
            if ((vi.y > p.y) != (vj.y > p.y) and
                p.x < (vj.x - vi.x) * (p.y - vi.y) / (vj.y - vi.y) + vi.x)
            {
                inside = !inside;
            }
            j = i;
        }
        return inside;
    }

    fn signedArea(vertices: []const Point, contour: Contour) f32 {
        if (contour.len < 3) return 0.0;
        var sum: f32 = 0;
        for (0..contour.len) |i| {
            const p1 = vertices[contour[i]];
            const p2 = vertices[contour[(i + 1) % contour.len]];
            sum += (p1.x * p2.y) - (p2.x * p1.y);
        }
        return sum * 0.5;
    }

    fn isEar(self: *const EarClipper, idx: usize) bool {
        if (self.reflex.items[idx] == .reflex) return false;

        const p_len = self.polygon.items.len;
        const prev_poly_idx = (idx + p_len - 1) % p_len;
        const next_poly_idx = (idx + 1) % p_len;

        const prev = self.polygon.items[prev_poly_idx];
        const curr = self.polygon.items[idx];
        const next = self.polygon.items[next_poly_idx];

        for (self.reflex.items, 0..) |t, i| {
            if (i == idx or i == prev_poly_idx or i == next_poly_idx) continue;
            if (t == .reflex) {
                if (pointInTriangle(
                    self.vertices[self.polygon.items[i]],
                    self.vertices[prev],
                    self.vertices[curr],
                    self.vertices[next],
                )) return false;
            }
        }

        return true;
    }

    fn classifyVertex(self: *const EarClipper, idx: usize) VertexClass {
        const p_len = self.polygon.items.len;
        const prev_idx = self.polygon.items[(idx + p_len - 1) % p_len];
        const curr_idx = self.polygon.items[idx];
        const next_idx = self.polygon.items[(idx + 1) % p_len];
        return if (isConvex(self.vertices[prev_idx], self.vertices[curr_idx], self.vertices[next_idx], self.winding_sign)) .convex else .reflex;
    }

    // ── Hole merging ────────────────────────────────────────────────────

    fn eliminateHoles(self: *EarClipper, outer: Contour, holes: []const Contour) ![]usize {
        if (holes.len == 0) return self.gpa.dupe(usize, outer);

        var current_outer = try self.gpa.dupe(usize, outer);
        errdefer self.gpa.free(current_outer);

        for (holes) |hole| {
            const merged = try self.mergeHoleIntoOuter(current_outer, hole);
            self.gpa.free(current_outer);
            current_outer = merged;
        }

        return current_outer;
    }

    fn findRightmostVertex(self: *const EarClipper, hole: Contour) usize {
        std.debug.assert(hole.len > 0);

        var max_pos: usize = 0;
        var max_x: f32 = self.vertices[hole[0]].x;
        for (hole, 0..) |v_idx, pos| {
            const x = self.vertices[v_idx].x;
            if (x > max_x or (x == max_x and self.vertices[v_idx].y > self.vertices[hole[max_pos]].y)) {
                max_pos = pos;
                max_x = x;
            }
        }
        return max_pos;
    }

    fn findBridgeVertex(self: *const EarClipper, outer: Contour, hole: Contour) usize {
        const hole_idx = self.findRightmostVertex(hole);
        const hole_pt = self.vertices[hole[hole_idx]];

        var best_pos: usize = 0;
        var min_dist: f32 = std.math.floatMax(f32);
        var intersect_pt: Point = undefined;
        var found_intersection = false;

        // Cast a horizontal ray rightward from the hole's rightmost vertex
        // and find the nearest intersection with the outer contour.
        for (0..outer.len) |i| {
            const a = self.vertices[outer[i]];
            const b = self.vertices[outer[(i + 1) % outer.len]];

            if ((a.x > hole_pt.x or b.x > hole_pt.x)) {
                if ((a.y <= hole_pt.y and b.y > hole_pt.y) or
                    (b.y <= hole_pt.y and a.y > hole_pt.y))
                {
                    const t = (hole_pt.y - a.y) / (b.y - a.y);
                    const ix = a.x + t * (b.x - a.x);

                    if (ix >= hole_pt.x) {
                        const dist_sq = (ix - hole_pt.x) * (ix - hole_pt.x);
                        if (dist_sq < min_dist) {
                            min_dist = dist_sq;
                            best_pos = if (a.x > b.x) i else (i + 1) % outer.len;
                            intersect_pt = .{ .x = ix, .y = hole_pt.y };
                            found_intersection = true;
                        }
                    }
                }
            }
        }

        if (!found_intersection) return best_pos;

        // Refine: pick the outer vertex inside the (hole_pt, intersect, best)
        // triangle that minimises the angle from hole_pt.
        const best_vertex = self.vertices[outer[best_pos]];
        var refined_pos = best_pos;
        var min_angle: f32 = std.math.floatMax(f32);

        for (0..outer.len) |i| {
            const v_pt = self.vertices[outer[i]];
            if (pointInTriangle(v_pt, hole_pt, intersect_pt, best_vertex)) {
                const angle = @abs(std.math.atan2(v_pt.y - hole_pt.y, v_pt.x - hole_pt.x));
                if (angle < min_angle) {
                    min_angle = angle;
                    refined_pos = i;
                }
            }
        }

        return refined_pos;
    }

    fn mergeHoleIntoOuter(self: *EarClipper, outer: Contour, hole: Contour) ![]usize {
        const outer_bridge = self.findBridgeVertex(outer, hole);
        const hole_bridge = self.findRightmostVertex(hole);

        // Result: outer[0..bridge] + hole (rotated to start at bridge) + bridge edges + outer[bridge+1..]
        const res = try self.gpa.alloc(usize, outer.len + hole.len + 2);
        var n: usize = 0;

        for (0..outer_bridge + 1) |i| {
            res[n] = outer[i];
            n += 1;
        }
        for (0..hole.len) |i| {
            res[n] = hole[(hole_bridge + i) % hole.len];
            n += 1;
        }
        res[n] = hole[hole_bridge];
        n += 1;
        res[n] = outer[outer_bridge];
        n += 1;
        for (outer_bridge + 1..outer.len) |i| {
            res[n] = outer[i];
            n += 1;
        }

        return res;
    }
};
