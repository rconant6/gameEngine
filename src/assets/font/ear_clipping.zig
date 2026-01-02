const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Point = @import("font_data.zig").V2;

const Contour = []const usize;
const Contours = []const []const usize;
const Triangle = [3]usize;

const ContourSet = struct {
    outer: Contour,
    holes: []const Contour,

    pub fn format(self: ContourSet, w: *std.Io.Writer) !void {
        try w.print(
            "CONTOUR SET: outerLen: {d}  holes count: {d}\n",
            .{ self.outer.len, self.holes.len },
        );
    }
};

const VertexClass = enum { convex, reflex };
const ContourClass = enum { outer, hole };

pub const EarClipper = struct {
    allocator: Allocator,
    vertices: []const Point,

    polygon: ArrayList(usize), // active vertex indices -shrinks over time...ordered indexes still alive in vertices
    reflex: ArrayList(VertexClass), // is vertex reflex? 1:1 w/ vertices
    triangles: ArrayList(Triangle), // output accumulator

    pub fn init(allocator: Allocator, vertices: []const Point) EarClipper {
        return .{
            .allocator = allocator,
            .vertices = vertices,
            .polygon = .empty,
            .reflex = .empty,
            .triangles = .empty,
        };
    }
    pub fn deinit(self: *EarClipper) void {
        self.polygon.deinit(self.allocator);
        self.reflex.deinit(self.allocator);
        self.triangles.deinit(self.allocator);
    }

    // Main entry point
    pub fn triangulate(self: *EarClipper, contours: []const Contour) ![]Triangle {
        // Separate contours into outers (CW) and holes (CCW)
        var outers: ArrayList(Contour) = .empty;
        defer outers.deinit(self.allocator);
        var holes: ArrayList(Contour) = .empty;
        defer holes.deinit(self.allocator);

        const epsilon = 0.000001; // Tolerance for near-zero signed area

        for (contours) |contour| {
            const val = signedArea(self.vertices, contour);

            // Skip degenerate contours with near-zero area (collinear points, etc.)
            if (@abs(val) < epsilon) {
                // std.debug.print("WARNING: Skipping degenerate contour with near-zero signed area ({d:.8})\n", .{val});
                continue;
            } else if (val < 0) {
                try outers.append(self.allocator, contour); // CW = outer
            } else if (val > 0) {
                try holes.append(self.allocator, contour); // CCW = hole
            }
        }

        if (outers.items.len == 0) return error.NoOuterContour;

        // For each outer contour, merge its holes and triangulate
        for (outers.items) |outer| {
            // Find holes that belong to this outer (simplified: just merge all holes into first outer)
            const holes_for_this_outer = if (outers.items.len == 1) holes.items else &[_]Contour{};

            const merged = try self.eliminateHoles(outer, holes_for_this_outer);
            defer self.allocator.free(merged);

            self.polygon.clearRetainingCapacity();
            self.reflex.clearRetainingCapacity();

            try self.polygon.appendSlice(self.allocator, merged);
            try self.clipEars();
        }

        return self.triangles.toOwnedSlice(self.allocator);
    }

    // Phase methods
    fn classifyContours(self: *EarClipper, contours: []const Contour) !ContourSet {
        var holes: ArrayList(Contour) = .empty;
        var outer: Contour = undefined;
        var seen_outer = false;

        for (contours) |contour| {
            const val = signedArea(self.vertices, contour);
            if (val < 0) {
                if (seen_outer) return error.MultipleOuterContours;
                outer = contour;
                seen_outer = true;
            } else if (val > 0) {
                try holes.append(self.allocator, contour);
            }
        }

        if (!seen_outer) return error.NoOuterContour;

        return .{
            .outer = outer,
            .holes = try holes.toOwnedSlice(self.allocator),
        };
    }

    fn eliminateHoles(self: *EarClipper, outer: Contour, holes: []const Contour) ![]usize {
        if (holes.len == 0) return self.allocator.dupe(usize, outer);
        var current_outer = try self.allocator.dupe(usize, outer);
        errdefer self.allocator.free(current_outer);

        for (holes) |hole| {
            const merged = try self.mergeHoleIntoOuter(current_outer, hole);
            self.allocator.free(current_outer); // Always free the old one before replacing
            current_outer = merged;
        }

        return current_outer;
    }
    fn clipEars(self: *EarClipper) !void {
        if (self.polygon.items.len < 3) return error.ToFewVerticesToClip;

        // Debug: print initial polygon state
        // std.debug.print("\nStarting clipEars with {} vertices\n", .{self.polygon.items.len});
        // for (0..@min(self.polygon.items.len, 10)) |i| {
        //     const v_idx = self.polygon.items[i];
        //     const v = self.vertices[v_idx];
        //     std.debug.print("  v[{}]: ({d:.6}, {d:.6})\n", .{ i, v.x, v.y });
        // }

        try self.reflex.ensureTotalCapacity(self.allocator, self.polygon.items.len);

        for (0..self.polygon.items.len) |i| {
            const classification = self.classifyVertex(i);
            self.reflex.appendAssumeCapacity(classification);
        }

        // Debug: check initial state
        // var initial_convex: usize = 0;
        // for (self.reflex.items) |class| {
        //     if (class == .convex) initial_convex += 1;
        // }
        // if (initial_convex == 0 and self.polygon.items.len > 3) {
        //     // std.debug.print("WARNING: clipEars starting with ALL reflex vertices (poly_len={})\n", .{self.polygon.items.len});
        //     for (0..@min(5, self.polygon.items.len)) |i| {
        //         const v_idx = self.polygon.items[i];
        //         const p_len = self.polygon.items.len;
        //         const prev_v_idx = self.polygon.items[(i + p_len - 1) % p_len];
        //         const next_v_idx = self.polygon.items[(i + 1) % p_len];
        //         const a = self.vertices[prev_v_idx];
        //         const b = self.vertices[v_idx];
        //         const c = self.vertices[next_v_idx];
        //         const edge1 = b.sub(a);
        //         const edge2 = c.sub(b);
        //         const cross = edge1.x * edge2.y - edge1.y * edge2.x;
        //         std.debug.print("  [{}/{}] idx={} cross={d:.6} class={s}\n", .{ i, self.polygon.items.len, v_idx, cross, @tagName(self.reflex.items[i]) });
        //     }
        // }

        var iterations: usize = 0;
        while (self.polygon.items.len > 3) {
            // Check if remaining polygon is degenerate (collinear or near-zero area)
            const remaining_area = signedArea(self.vertices, self.polygon.items);
            if (@abs(remaining_area) < 0.000001) {
                // std.debug.print("WARNING: Remaining polygon became degenerate (area={d:.8}), stopping early\n", .{remaining_area});
                // Just return what we have so far - skip the degenerate remainder
                return;
            }

            var ear_idx: ?usize = null;
            for (0..self.polygon.items.len) |i| {
                if (self.isEar(i)) {
                    ear_idx = i;
                    break;
                }
            }

            const ear = ear_idx orelse {
                // std.debug.print("\nNoEarFound at iter={} poly_len={}\n", .{ iterations, self.polygon.items.len });
                // var convex_cnt: usize = 0;
                // for (self.reflex.items) |c| {
                //     if (c == .convex) convex_cnt += 1;
                // }
                // std.debug.print("  convex_count={} reflex_count={}\n", .{ convex_cnt, self.reflex.items.len - convex_cnt });
                //
                // // Print first few vertices to see geometry
                // for (0..@min(self.polygon.items.len, 8)) |i| {
                //     const v_idx = self.polygon.items[i];
                //     const v = self.vertices[v_idx];
                //     std.debug.print("  v[{}]: ({d:.6}, {d:.6}) class={s}\n", .{ i, v.x, v.y, @tagName(self.reflex.items[i]) });
                // }
                return error.NoEarFound;
            };
            iterations += 1;
            const p_len = self.polygon.items.len;
            const prev_idx = (ear + p_len - 1) % p_len;
            const next_idx = (ear + 1) % p_len;
            const triangle: Triangle = .{
                self.polygon.items[prev_idx],
                self.polygon.items[ear],
                self.polygon.items[next_idx],
            };
            try self.triangles.append(self.allocator, triangle);

            _ = self.polygon.orderedRemove(ear);
            _ = self.reflex.orderedRemove(ear);

            std.debug.assert(self.polygon.items.len == self.reflex.items.len);

            // After removal, reclassify adjacent vertices
            // prev was at (ear-1), still at (ear-1) if ear > 0, else at end
            // next was at (ear+1), now at (ear) after removal
            const new_len = self.polygon.items.len;
            if (new_len > 0) {
                const new_prev_idx = if (ear > 0) ear - 1 else new_len - 1;
                const new_next_idx = if (ear < new_len) ear else 0;

                self.reflex.items[new_prev_idx] = self.classifyVertex(new_prev_idx);
                self.reflex.items[new_next_idx] = self.classifyVertex(new_next_idx);
            }
        }

        std.debug.assert(self.polygon.items.len == 3);
        try self.triangles.append(self.allocator, .{
            self.polygon.items[0],
            self.polygon.items[1],
            self.polygon.items[2],
        });
    }

    // Geometry helpers (don't need self, but keep them in namespace)
    // For clockwise winding (TrueType fonts), convex vertices have negative cross product
    fn isConvex(a: Point, b: Point, c: Point) bool {
        const edge1 = b.sub(a);
        const edge2 = c.sub(b);
        const cross = edge1.x * edge2.y - edge1.y * edge2.x;
        return cross < 0;
    }
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
        if (denom == 0) return false;

        const inv_denom = 1.0 / denom;
        const u = (d11 * d20 - d01 * d21) * inv_denom;
        const v = (d00 * d21 - d01 * d20) * inv_denom;

        // Strict interior test with small epsilon to avoid edge cases
        const eps = 0.0001;
        return (u > eps) and (v > eps) and (u + v < 1.0 - eps);
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

        const p_len = self.polygon.items.len; // looking at active vertices
        const prev_poly_idx = (idx + p_len - 1) % p_len;
        const next_poly_idx = (idx + 1) % p_len;

        const prev = self.polygon.items[prev_poly_idx];
        const curr = self.polygon.items[idx];
        const next = self.polygon.items[next_poly_idx];

        for (self.reflex.items, 0..) |t, i| {
            // Skip vertices that are part of the triangle
            if (i == idx or i == prev_poly_idx or i == next_poly_idx) continue;

            if (t == .reflex) {
                const vertex_idx = self.polygon.items[i];
                if (pointInTriangle(
                    self.vertices[vertex_idx],
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

        return if (isConvex(self.vertices[prev_idx], self.vertices[curr_idx], self.vertices[next_idx])) .convex else .reflex;
    }

    // Hole merging helpers
    fn findRightmostVertex(self: *const EarClipper, hole: Contour) usize {
        std.debug.assert(hole.len > 0);

        var max_pos: usize = 0; // Position in hole array, not vertex index
        var max_x: f32 = self.vertices[hole[0]].x;
        for (hole, 0..) |v_idx, pos| {
            const vertex = self.vertices[v_idx];
            if (vertex.x >= max_x) {
                if (vertex.x == max_x) {
                    if (vertex.y > self.vertices[hole[max_pos]].y) {
                        max_pos = pos;
                        max_x = vertex.x;
                    } else continue;
                }
                max_pos = pos;
                max_x = vertex.x;
            }
        }

        return max_pos;
    }
    fn findBridgeVertex(self: *const EarClipper, outer: Contour, hole: Contour) usize {
        const hole_idx = self.findRightmostVertex(hole);
        const hole_pt = self.vertices[hole[hole_idx]];

        var best_pos: usize = 0; // Position in outer array, not vertex index
        var min_dist: f32 = std.math.floatMax(f32);
        var intersect_pt: Point = undefined;
        var found_intersection = false;

        // Step 1: Find the closest ray intersection with the outer contour
        for (0..outer.len) |i| {
            const a_idx = outer[i];
            const b_idx = outer[(i + 1) % outer.len];
            const a = self.vertices[a_idx];
            const b = self.vertices[b_idx];

            if ((a.x > hole_pt.x or b.x > hole_pt.x)) { // edge that are to the right
                if ((a.y <= hole_pt.y and b.y > hole_pt.y) or
                    (b.y <= hole_pt.y and a.y > hole_pt.y))
                {
                    const t = (hole_pt.y - a.y) / (b.y - a.y);
                    const intersect_x = a.x + t * (b.x - a.x);

                    if (intersect_x >= hole_pt.x) {
                        const dist_sq = (intersect_x - hole_pt.x) * (intersect_x - hole_pt.x);
                        if (dist_sq < min_dist) {
                            min_dist = dist_sq;
                            best_pos = if (a.x > b.x) i else (i + 1) % outer.len;
                            intersect_pt = .{ .x = intersect_x, .y = hole_pt.y };
                            found_intersection = true;
                        }
                    }
                }
            }
        }

        if (!found_intersection) return best_pos;

        // Step 2: Refine by checking if any outer vertices lie inside the triangle
        // formed by (hole_pt, intersect_pt, best_vertex)
        const best_vertex = self.vertices[outer[best_pos]];

        var refined_pos = best_pos;
        var min_angle: f32 = std.math.floatMax(f32);

        for (0..outer.len) |i| {
            const v_pt = self.vertices[outer[i]];

            // Check if this vertex is inside the triangle (hole_pt, intersect_pt, best_vertex)
            if (pointInTriangle(v_pt, hole_pt, intersect_pt, best_vertex)) {
                // Calculate angle from hole_pt to this vertex
                const dx = v_pt.x - hole_pt.x;
                const dy = v_pt.y - hole_pt.y;
                const angle = @abs(std.math.atan2(dy, dx));

                if (angle < min_angle) {
                    min_angle = angle;
                    refined_pos = i;
                }
            }
        }

        return refined_pos;
    }
    fn mergeHoleIntoOuter(self: *EarClipper, outer: Contour, hole: Contour) ![]usize {
        const new_len = outer.len + hole.len + 2;
        const res = try self.allocator.alloc(usize, new_len);

        const outer_bridge_pos = self.findBridgeVertex(outer, hole);
        const hole_bridge_pos = self.findRightmostVertex(hole);

        var res_idx: usize = 0;
        // Initial Outer and bridge
        for (0..outer_bridge_pos + 1) |i| {
            res[res_idx] = outer[i];
            res_idx += 1;
        }
        // Insert hole w/ bridge
        for (0..hole.len) |i| {
            const idx = (hole_bridge_pos + i) % hole.len;
            res[res_idx] = hole[idx];
            res_idx += 1;
        }
        // Put bridge in as well
        res[res_idx] = hole[hole_bridge_pos];
        res_idx += 1;
        res[res_idx] = outer[outer_bridge_pos];
        res_idx += 1;
        // Put rest of outer in
        for (outer_bridge_pos + 1..outer.len) |i| {
            res[res_idx] = outer[i];
            res_idx += 1;
        }

        return res;
    }
};
