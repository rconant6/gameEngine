const std = @import("std");
const Allocator = std.mem.Allocator;
const cols = @import("color.zig");
const Color = cols.Color;
const math = @import("math");
const V2 = math.V2;
const reg = @import("registry");
const ShapeData = reg.ShapeData;
const Shapes = @import("shapes");
const Batch = @import("batch.zig").Batch;
const rt = @import("render_types.zig");
const DrawStyle = rt.DrawStyle;
const RenderContext = rt.RenderContext;
const Transform = rt.Transform;
const log = @import("debug").log;

const seg_buckets = [_]u32{ 8, 12, 16, 24, 32, 48, 64, 96 };
// NOTE: ensure seg_buckets is ascending, will cause unusual display behavior
comptime {
    for (seg_buckets[1..], 1..) |bucket, i| {
        if (bucket <= seg_buckets[i - 1])
            @compileError("seg_buckets must be strictly ascending");
    }
}
const MAX_SEG: usize = seg_buckets[seg_buckets.len - 1];
const CHORD_GAP_PX: f32 = 0.33; // its subpixel you 'can't see'

const unit_rings: [seg_buckets.len][MAX_SEG]V2 = blk: {
    var rings: [seg_buckets.len][MAX_SEG]V2 = undefined;
    for (seg_buckets, 0..) |count, b| {
        const stepf: f32 = std.math.tau / @as(f32, @floatFromInt(count));
        for (0..count) |i| {
            const fi: f32 = @floatFromInt(i);
            rings[b][i] = direction(fi * stepf);
        }
    }

    break :blk rings;
};

fn bucketFor(radius_world: f32, px_per_unit: f32) usize {
    const r_px = radius_world * px_per_unit;
    if (r_px <= CHORD_GAP_PX) return 0;

    const ideal = @divExact(std.math.pi, std.math.acos(1 - CHORD_GAP_PX / r_px));
    inline for (seg_buckets, 0..) |count, idx| {
        if (@as(f32, count) >= ideal) return idx;
    }

    return seg_buckets.len - 1;
}

pub const ClipMap = struct {
    scale: [2]f32 = .{0} ** 2,
    offset: [2]f32 = .{0} ** 2,

    // camera + ortho + aspect -> scale/offset.
    // world→clip: (p - cam) / (ortho * {aspect, 1}), factored to p*scale + offset.
    pub fn fromWorld(ctx: RenderContext) ClipMap {
        const aspect = ctx.aspectRatio();
        const sx = 1.0 / (ctx.ortho_size * aspect);
        const sy = 1.0 / ctx.ortho_size;
        return .{
            .scale = .{ sx, sy },
            .offset = .{ -ctx.camera_loc.x * sx, -ctx.camera_loc.y * sy },
        };
    }
    // pixels -> clip (w/ y-flip). x: (sx/w)*2 - 1;  y: 1 - (sy/h)*2 (flip = -y scale).
    pub fn fromScreen(ctx: RenderContext) ClipMap {
        const fw: f32 = @floatFromInt(ctx.width);
        const fh: f32 = @floatFromInt(ctx.height);
        return .{
            .scale = .{ 2.0 / fw, -2.0 / fh },
            .offset = .{ -1.0, 1.0 },
        };
    }
    // p * scale + offset
    pub inline fn apply(self: ClipMap, p: V2) [2]f32 {
        return .{
            p.x * self.scale[0] + self.offset[0],
            p.y * self.scale[1] + self.offset[1],
        };
    }
};

// build once per shape
pub const LocalXform = struct {
    m00: f32,
    m01: f32,
    m10: f32,
    m11: f32,
    tx: f32,
    ty: f32,

    // (scale, rotate, translate). rotate∘scale = [[s·c, -s·s],[s·s, s·c]].
    pub fn from(t: ?Transform) LocalXform {
        const tf = t orelse return identity;
        const s = tf.scale orelse 1.0;
        const rot = tf.rotation orelse 0.0;
        const off = tf.offset orelse V2{ .x = 0, .y = 0 };
        const c = @cos(rot);
        const sn = @sin(rot);
        return .{
            .m00 = s * c,
            .m01 = -s * sn,
            .m10 = s * sn,
            .m11 = s * c,
            .tx = off.x,
            .ty = off.y,
        };
    }
    pub const identity: LocalXform = .{
        .m00 = 1,
        .m01 = 0,
        .m10 = 0,
        .m11 = 1,
        .tx = 0,
        .ty = 0,
    };
    // 4 muls + 4 adds, no branching. [m]·p + t
    pub inline fn apply(self: LocalXform, p: V2) V2 {
        return .{
            .x = self.m00 * p.x + self.m01 * p.y + self.tx,
            .y = self.m10 * p.x + self.m11 * p.y + self.ty,
        };
    }
};

const GradPaint = struct {
    kind: enum { linear, radial },
    start: [4]f32, // linear, opacity already applied
    end: [4]f32,
    // linear: unit axis dir + projection range [lo, lo+span] along it
    axis: V2 = .{ .x = 1, .y = 0 },
    lo: f32 = 0,
    span: f32 = 1,
    // radial: center + max radius (perimeter)
    center: V2 = .{ .x = 0, .y = 0 },
    radius: f32 = 1,
};

// Per-vertex color source. Fill hands emit a gradient paint (when set) or flat;
// stroke always hands flat. Evaluated in LOCAL (post-LocalXform) space so the
// gradient rotates/scales with the shape.
const Paint = union(enum) {
    flat: [4]f32,
    grad: GradPaint,

    fn at(self: Paint, local_p: V2) [4]f32 {
        switch (self) {
            .flat => |f| return f,
            .grad => |g| {
                const t = switch (g.kind) {
                    .linear => std.math.clamp(
                        (local_p.dot(g.axis) - g.lo) / g.span,
                        0.0,
                        1.0,
                    ),
                    .radial => std.math.clamp(
                        local_p.sub(g.center).magnitude() / g.radius,
                        0.0,
                        1.0,
                    ),
                };
                // linear-space component lerp (correct gradient interpolation)
                return .{
                    g.start[0] + (g.end[0] - g.start[0]) * t,
                    g.start[1] + (g.end[1] - g.start[1]) * t,
                    g.start[2] + (g.end[2] - g.start[2]) * t,
                    g.start[3] + (g.end[3] - g.start[3]) * t,
                };
            },
        }
    }
};

fn Tess(comptime V: type, comptime K: type) type {
    return struct {
        const Self = @This();
        batch: *Batch(V, K),
        makeVertex: *const fn ([2]f32, [4]f32, u16) V,
        xform_index: u16,
        tri_key: K, // triangle draw-call key
        hw: f32,
        px_per_unit: f32,

        fn emit(self: Self, p: V2, paint: Paint) !void {
            const color = paint.at(p);

            try self.batch.vertex(self.makeVertex(
                .{ p.x, p.y },
                color,
                self.xform_index,
            ));
        }

        fn emitSegment(self: Self, p0: V2, p1: V2, paint: Paint, hw: f32) !void {
            const dir = p1.sub(p0).normalize();
            const norm = dir.perp();

            const a = p0.add(norm.mul(hw));
            const b = p0.sub(norm.mul(hw));
            const e = p1.add(norm.mul(hw));
            const f = p1.sub(norm.mul(hw));

            try self.emit(a, paint);
            try self.emit(b, paint);
            try self.emit(e, paint);
            try self.emit(e, paint);
            try self.emit(b, paint);
            try self.emit(f, paint);
        }

        fn arcSegment(self: Self, radius: f32, sweep: f32) u32 {
            const bucket = bucketFor(radius, self.px_per_unit);
            const full_n = seg_buckets[bucket];
            return @intFromFloat(
                @max(
                    2.0,
                    @ceil(full_n * @abs(sweep) / std.math.tau),
                ),
            );
        }

        // Resolve a shape's fill into a Paint. No gradient → flat. Gradient →
        // radial keys off center/radius directly; linear projects the shape's
        // extent (center ± radius along the axis) into a [lo, lo+span] range.
        // center/radius are in the shape's own (pre-transform) space, matching
        // where emit evaluates the gradient.
        fn buildFillPaint(_: Self, style: DrawStyle, fc: Color, center: V2, radius: f32) Paint {
            const g = style.gradient orelse
                return .{ .flat = fc.linearOpacity(style.opacity) };

            const start = g.start_color.linearOpacity(style.opacity);
            const end = g.end_color.linearOpacity(style.opacity);

            switch (g.kind) {
                .radial => return .{ .grad = .{
                    .kind = .radial,
                    .start = start,
                    .end = end,
                    .center = center,
                    .radius = @max(radius, 0.0001),
                } },
                .linear => {
                    const axis = direction(g.angle);
                    // extent along axis: center projection ± radius
                    const mid = center.dot(axis);
                    return .{ .grad = .{
                        .kind = .linear,
                        .start = start,
                        .end = end,
                        .axis = axis,
                        .lo = mid - radius,
                        .span = @max(2.0 * radius, 0.0001),
                    } };
                },
            }
        }

        fn strokeClosed(self: Self, points: []const V2, style: DrawStyle) !void {
            if (points.len < 2) return;

            const paint = Paint{ .flat = style.stroke.?.linearOpacity(style.opacity) };
            const hw = self.hw;
            const start = self.batch.mark();

            const n = points.len;
            for (0..n) |i| {
                const p0 = points[i];
                const p1 = points[(i + 1) % n];

                try self.emitSegment(p0, p1, paint, hw);
            }
            try self.batch.pushCall(
                self.tri_key,
                start,
                self.batch.mark() - start,
            );
        }

        fn strokeOpen(self: Self, points: []const V2, style: DrawStyle) !void {
            if (points.len < 2) return;

            const paint = Paint{ .flat = style.stroke.?.linearOpacity(style.opacity) };
            const hw = self.hw;
            const start = self.batch.mark();

            const n = points.len - 1;
            for (0..n) |i| {
                const p0 = points[i];
                const p1 = points[i + 1];

                try self.emitSegment(p0, p1, paint, hw);
            }
            try self.batch.pushCall(
                self.tri_key,
                start,
                self.batch.mark() - start,
            );
        }

        fn arcPoints(
            self: Self,
            buf: []V2,
            origin: V2,
            radius: f32,
            start: f32,
            end: f32,
        ) usize {
            const sweep = end - start;
            const bucket = bucketFor(radius, self.px_per_unit);
            const full_n = seg_buckets[bucket];
            var n: u32 = @intFromFloat(@max(2.0, @ceil(@as(f32, @floatFromInt(full_n)) * @abs(sweep) / std.math.tau)));
            n = @min(n, buf.len);
            const step: f32 = sweep / @as(f32, @floatFromInt((n - 1)));
            for (0..n) |i| {
                const fi: f32 = @floatFromInt(i);
                const point: V2 = direction(step * fi);
                buf[i] = origin.add(point.mul(radius));
            }

            return n;
        }

        fn circle(self: Self, c: Shapes.Circle, style: DrawStyle) !void {
            if (style.fillColor() == null and style.stroke == null) return;

            const bucket = bucketFor(c.radius, self.px_per_unit);
            const num_steps = seg_buckets[bucket];
            const ring = unit_rings[bucket];

            var pts: [MAX_SEG]V2 = undefined;
            for (0..num_steps) |i| {
                pts[i] = c.origin.add(ring[i].mul(c.radius));
            }
            const perimeter = pts[0..num_steps];

            if (style.fillColor()) |fc| {
                const paint = self.buildFillPaint(style, fc, c.origin, c.radius);
                const start = self.batch.mark();
                for (0..num_steps) |i| {
                    try self.emit(c.origin, paint);
                    try self.emit(perimeter[i], paint);
                    try self.emit(perimeter[(i + 1) % num_steps], paint);
                }
                try self.batch.pushCall(
                    self.tri_key,
                    start,
                    self.batch.mark() - start,
                );
            }

            if (style.stroke) |_| {
                try self.strokeClosed(perimeter, style);
            }
        }

        fn ellipse(self: Self, e: Shapes.Ellipse, style: DrawStyle) !void {
            if (style.fillColor() == null and style.stroke == null) return;

            const bucket = bucketFor(@max(e.semi_major, e.semi_minor), self.px_per_unit);
            const num_steps = seg_buckets[bucket];
            const ring = unit_rings[bucket];

            var pts: [MAX_SEG]V2 = undefined;
            for (0..num_steps) |i| {
                const u = ring[i];
                pts[i] = e.origin.add(.{ .x = u.x * e.semi_major, .y = u.y * e.semi_minor });
            }
            const perimeter = pts[0..num_steps];

            if (style.fillColor()) |fc| {
                const paint = self.buildFillPaint(style, fc, e.origin, @max(e.semi_major, e.semi_minor));
                const start = self.batch.mark();
                for (0..num_steps) |i| {
                    try self.emit(e.origin, paint);
                    try self.emit(perimeter[i], paint);
                    try self.emit(perimeter[(i + 1) % num_steps], paint);
                }
                try self.batch.pushCall(
                    self.tri_key,
                    start,
                    self.batch.mark() - start,
                );
            }

            if (style.stroke) |_| {
                try self.strokeClosed(perimeter, style);
            }
        }
        fn arc(self: Self, a: Shapes.Arc, style: DrawStyle) !void {
            if (style.fillColor() == null and style.stroke == null) return;

            const sweep = a.end_angle - a.start_angle;
            if (@abs(sweep) >= std.math.tau) {
                try self.circle(.{
                    .origin = a.origin,
                    .radius = a.radius,
                }, style);
                return;
            }

            const r_out = a.radius;
            const r_in = a.radius - a.thickness;
            std.debug.assert(0 <= r_in and r_in <= r_out);

            if (a.thickness == 0) {
                var buf: [MAX_SEG + 1]V2 = undefined;
                buf[0] = a.origin;
                const n = arcSegs(a.radius, sweep, self.px_per_unit);
                const len = n + 1;
                arcInto(buf[1..len], a.origin, a.radius, a.start_angle, a.end_angle, n);
                const perimeter = buf[0..len];

                if (style.fillColor()) |fc| {
                    const paint = self.buildFillPaint(style, fc, a.origin, a.radius);

                    const start = self.batch.mark();
                    for (0..n) |i| {
                        try self.emit(perimeter[0], paint);
                        try self.emit(perimeter[i], paint);
                        try self.emit(perimeter[i + 1], paint);
                    }

                    try self.batch.pushCall(
                        self.tri_key,
                        start,
                        self.batch.mark() - start,
                    );
                }

                if (style.stroke) |_| {
                    try self.strokeClosed(perimeter, style);
                }
            } else {
                const n = arcSegs(r_out, sweep, self.px_per_unit);
                var buf: [2 * MAX_SEG]V2 = undefined;

                arcInto(buf[0..], a.origin, r_out, a.start_angle, a.end_angle, n);
                arcInto(buf[n..], a.origin, r_in, a.end_angle, a.start_angle, n);

                if (style.fillColor()) |fc| {
                    const paint = self.buildFillPaint(style, fc, a.origin, r_out);
                    const start = self.batch.mark();

                    for (0..n - 1) |i| {
                        const outer0 = buf[i];
                        const outer1 = buf[i + 1];
                        const inner0 = buf[2 * n - 1 - i];
                        const inner1 = buf[2 * n - 2 - i];

                        try self.emit(outer0, paint);
                        try self.emit(inner0, paint);
                        try self.emit(outer1, paint);

                        try self.emit(outer1, paint);
                        try self.emit(inner0, paint);
                        try self.emit(inner1, paint);
                    }

                    try self.batch.pushCall(
                        self.tri_key,
                        start,
                        self.batch.mark() - start,
                    );
                }

                if (style.stroke) |_| {
                    try self.strokeClosed(buf[0 .. 2 * n], style);
                }
            }
        }

        fn capsule(self: Self, c: Shapes.Capsule, style: DrawStyle) !void {
            if (style.fillColor() == null and style.stroke == null) return;
            const pi: f32 = std.math.pi;

            const horizontal = c.half_width >= c.half_height;

            const r = @min(c.half_width, c.half_height);
            const off = if (horizontal) c.half_width - r else c.half_height - r;
            const right_c = if (horizontal) c.center.add(
                .{ .x = off, .y = 0 },
            ) else c.center.add(
                .{ .x = 0, .y = off },
            );
            const left_c = if (horizontal) c.center.add(
                .{ .x = -off, .y = 0 },
            ) else c.center.add(
                .{ .x = 0, .y = -off },
            );
            const angle_idx: usize = if (horizontal) 0 else 4;
            const n = arcSegs(r, std.math.pi, self.px_per_unit);
            const angles: [8]f32 = .{
                -pi / 2.0, pi / 2.0, pi / 2.0, 3 * pi / 2.0,
                0.0,       pi,       pi,       2 * pi,
            };

            var buf: [2 * MAX_SEG]V2 = undefined;
            var w: usize = 0;
            arcInto(
                buf[w..],
                right_c,
                r,
                angles[angle_idx],
                angles[angle_idx + 1],
                n,
            );
            w += n;
            arcInto(
                buf[w..],
                left_c,
                r,
                angles[angle_idx + 2],
                angles[angle_idx + 3],
                n,
            );
            w += n;
            const perimeter = buf[0..w];

            if (style.fillColor()) |fc| {
                const paint = self.buildFillPaint(
                    style,
                    fc,
                    c.center,
                    @max(c.half_width, c.half_height),
                );

                const start = self.batch.mark();
                for (0..w) |i| {
                    try self.emit(c.center, paint);
                    try self.emit(perimeter[i], paint);
                    try self.emit(perimeter[@mod((i + 1), w)], paint);
                }

                try self.batch.pushCall(
                    self.tri_key,
                    start,
                    self.batch.mark() - start,
                );
            }

            if (style.stroke) |_| {
                try self.strokeClosed(perimeter, style);
            }
        }

        fn line(self: Self, l: Shapes.Line, style: DrawStyle) !void {
            if (style.fillColor() == null and style.stroke == null) return;

            if (style.stroke) |_| {
                try self.strokeOpen(
                    &.{ l.start, l.end },
                    style,
                );
            }
        }

        fn polyline(self: Self, l: Shapes.PolyLine, style: DrawStyle) !void {
            if (style.fillColor() == null and style.stroke == null) return;

            if (style.stroke) |_| {
                try self.strokeOpen(
                    l.points,
                    style,
                );
            }
        }

        fn poly(self: Self, p: Shapes.Polygon, style: DrawStyle) !void {
            if (style.fillColor() == null and style.stroke == null) return;

            if (style.fillColor()) |fc| {
                const cache = p.triangle_cache orelse return error.InvalidPolygon;
                // radius = farthest point from centroid (for radial/linear extent)
                var rad: f32 = 0.0001;
                for (p.points) |pt| rad = @max(rad, pt.sub(p.center).magnitude());
                const paint = self.buildFillPaint(style, fc, p.center, rad);
                const start = self.batch.mark();
                for (cache) |t| {
                    try self.emit(t[0], paint);
                    try self.emit(t[1], paint);
                    try self.emit(t[2], paint);
                }
                try self.batch.pushCall(self.tri_key, start, self.batch.mark() - start);
            }
            if (style.stroke) |_| {
                try self.strokeClosed(p.points, style);
            }
        }

        fn nGon(self: Self, g: Shapes.NGon, style: DrawStyle) !void {
            if (style.fillColor() == null and style.stroke == null) return;

            const n = std.math.clamp(g.sides, 3, MAX_SEG);
            const step: f32 = std.math.tau / @as(f32, @floatFromInt(g.sides));

            var points: [MAX_SEG]V2 = undefined;
            for (0..n) |i| {
                const fi: f32 = @floatFromInt(i);
                points[i] = g.origin.add(.{
                    .x = @cos(fi * step),
                    .y = @sin(fi * step),
                });
            }

            if (style.fillColor()) |fc| {
                const paint = self.buildFillPaint(style, fc, g.origin, g.radius);
                const start = self.batch.mark();

                for (0..n) |i| {
                    try self.emit(g.origin, paint);
                    try self.emit(points[i], paint);
                    try self.emit(points[@mod((i + 1), n)], paint);
                }

                try self.batch.pushCall(
                    self.tri_key,
                    start,
                    self.batch.mark() - start,
                );
            }

            if (style.stroke) |_| {
                try self.strokeClosed(points[0..g.sides], style);
            }
        }

        fn star(self: Self, s: Shapes.Star, style: DrawStyle) !void {
            if (style.fillColor() == null and style.stroke == null) return;

            const n = std.math.clamp(s.points, 2, MAX_SEG / 2);
            const w = 2 * n;
            const step = std.math.tau / @as(f32, @floatFromInt(w));

            var points: [MAX_SEG]V2 = undefined;
            for (0..w) |i| {
                const r = if (i & 1 == 0) s.outer_radius else s.inner_radius;
                const fi: f32 = @floatFromInt(i);
                const point = s.origin.add(direction(step * fi));
                points[i] = point.mul(r);
            }

            if (style.fillColor()) |fc| {
                const paint = self.buildFillPaint(style, fc, s.origin, s.outer_radius);
                const start = self.batch.mark();

                for (0..w) |i| {
                    try self.emit(s.origin, paint);
                    try self.emit(points[i], paint);
                    try self.emit(points[@mod((i + 1), w)], paint);
                }

                try self.batch.pushCall(
                    self.tri_key,
                    start,
                    self.batch.mark() - start,
                );
            }

            if (style.stroke) |_| {
                try self.strokeClosed(points[0..w], style);
            }
        }

        fn rect(self: Self, r: Shapes.Rectangle, style: DrawStyle) !void {
            if (style.fillColor() == null and style.stroke == null) return;

            const corners = r.getCorners();
            if (style.fillColor()) |fc| {
                const half_diag = (V2{ .x = r.half_width, .y = r.half_height }).magnitude();
                const paint = self.buildFillPaint(style, fc, r.center, half_diag);
                const start = self.batch.mark();

                try self.emit(corners[0], paint);
                try self.emit(corners[1], paint);
                try self.emit(corners[2], paint);
                try self.emit(corners[0], paint);
                try self.emit(corners[2], paint);
                try self.emit(corners[3], paint);

                try self.batch.pushCall(
                    self.tri_key,
                    start,
                    self.batch.mark() - start,
                );
            }
            if (style.stroke) |_| {
                try self.strokeClosed(
                    &corners,
                    style,
                );
            }
        }

        fn roundedRect(self: Self, r: Shapes.RoundedRect, style: DrawStyle) !void {
            if (style.fillColor() == null and style.stroke == null) return;
            const pi: f32 = std.math.pi;

            const rad = @min(r.radius, r.half_width, r.half_height);
            const ix = r.half_width - rad;
            const iy = r.half_height - rad;
            const c_tr = r.center.add(.{ .x = ix, .y = iy });
            const c_tl = r.center.add(.{ .x = -ix, .y = iy });
            const c_bl = r.center.add(.{ .x = -ix, .y = -iy });
            const c_br = r.center.add(.{ .x = ix, .y = -iy });
            const n = arcSegs(rad, pi / 2.0, self.px_per_unit);

            var buf: [4 * MAX_SEG]V2 = undefined;
            var w: usize = 0;
            arcInto(buf[w..], c_tr, rad, 0.0, pi / 2.0, n);
            w += n;
            arcInto(buf[w..], c_tl, rad, pi / 2.0, pi, n);
            w += n;
            arcInto(buf[w..], c_bl, rad, pi, 3.0 * pi / 2.0, n);
            w += n;
            arcInto(buf[w..], c_br, rad, 3.0 * pi / 2.0, 2.0 * pi, n);
            w += n;
            const perimeter = buf[0..w];

            if (style.fillColor()) |fc| {
                const half_diag = (V2{ .x = r.half_width, .y = r.half_height }).magnitude();
                const paint = self.buildFillPaint(style, fc, r.center, half_diag);
                const start = self.batch.mark();
                for (0..w) |i| {
                    try self.emit(r.center, paint);
                    try self.emit(perimeter[i], paint);
                    try self.emit(perimeter[(i + 1) % w], paint);
                }
                try self.batch.pushCall(
                    self.tri_key,
                    start,
                    self.batch.mark() - start,
                );
            }

            if (style.stroke) |_| {
                try self.strokeClosed(
                    perimeter,
                    style,
                );
            }
        }

        fn tri(self: Self, t: Shapes.Triangle, style: DrawStyle) !void {
            if (style.fillColor()) |fc| {
                const centroid = t.v0.add(t.v1).add(t.v2).mul(1.0 / 3.0);
                var rad: f32 = 0.0001;
                for ([_]V2{ t.v0, t.v1, t.v2 }) |v| rad = @max(rad, v.sub(centroid).magnitude());
                const paint = self.buildFillPaint(style, fc, centroid, rad);
                const start = self.batch.mark();

                try self.emit(t.v0, paint);
                try self.emit(t.v1, paint);
                try self.emit(t.v2, paint);

                try self.batch.pushCall(self.tri_key, start, self.batch.mark() - start);
            }
            if (style.stroke) |_| {
                try self.strokeClosed(
                    &.{ t.v0, t.v1, t.v2 },
                    style,
                );
            }
        }
    };
}

pub fn tessellate(
    comptime V: type,
    comptime K: type,
    batch: *Batch(V, K),
    comptime makeVertex: fn ([2]f32, [4]f32, u16) V,
    tri_key: K,
    shape: ShapeData,
    xf_idx: u16,
    style: DrawStyle,
    hw: f32,
    px_per_unit: f32,
) !void {
    const ts = Tess(V, K){
        .batch = batch,
        .makeVertex = makeVertex,
        .xform_index = xf_idx,
        .tri_key = tri_key,
        .hw = hw,
        .px_per_unit = px_per_unit,
    };

    switch (shape) {
        .Arc => |a| try ts.arc(a, style),
        .Capsule => |c| try ts.capsule(c, style),
        .Circle => |c| try ts.circle(c, style),
        .Ellipse => |e| try ts.ellipse(e, style),
        .Line => |l| try ts.line(l, style),
        .NGon => |n| try ts.nGon(n, style),
        .PolyLine => |p| try ts.polyline(p, style),
        .Polygon => |p| try ts.poly(p, style),
        .Rectangle => |r| try ts.rect(r, style),
        .RoundedRect => |rr| try ts.roundedRect(rr, style),
        .Star => |s| try ts.star(s, style),
        .Triangle => |t| try ts.tri(t, style),
    }
}

pub fn arcSegs(radius: f32, sweep: f32, px_per_unit: f32) usize {
    const bucket = bucketFor(radius, px_per_unit);
    const full_len = @as(f32, @floatFromInt(seg_buckets[bucket]));

    return @as(
        usize,
        @intFromFloat(
            @max(2, @ceil(full_len * @abs(sweep) / std.math.tau)),
        ),
    );
}

pub fn arcInto(buf: []V2, center: V2, radius: f32, start: f32, end: f32, n: usize) void {
    const step = (end - start) / @as(f32, @floatFromInt(n - 1));
    for (0..n) |i| {
        const ang = start + @as(f32, @floatFromInt(i)) * step;
        buf[i] = center.add(direction(ang).mul(radius));
    }
}

inline fn direction(ang: f32) V2 {
    return .{
        .x = @cos(ang),
        .y = @sin(ang),
    };
}
