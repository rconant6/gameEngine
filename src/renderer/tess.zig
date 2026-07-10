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

    // identity when null; cos/sin once. Bakes the old transformPoint order
    // (scale, THEN rotate, THEN translate). rotate∘scale = [[s·c, -s·s],[s·s, s·c]].
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
    const identity: LocalXform = .{
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

fn Tess(comptime V: type, comptime K: type) type {
    return struct {
        const Self = @This();
        batch: *Batch(V, K),
        makeVertex: *const fn ([2]f32, u32) V, // backend vertex builder
        xf: LocalXform,
        map: ClipMap,
        tri_key: K, // triangle draw-call key
        hw: f32,
        px_per_unit: f32,

        fn emit(self: Self, p: V2, color: u32) !void {
            const local = self.xf.apply(p);
            const clip = self.map.apply(local);

            try self.batch.vertex(self.makeVertex(clip, color));
        }

        fn emitSegment(self: Self, p0: V2, p1: V2, pc: u32, hw: f32) !void {
            const dir = p1.sub(p0).normalize();
            const norm = dir.perp();

            const a = p0.add(norm.mul(hw));
            const b = p0.sub(norm.mul(hw));
            const e = p1.add(norm.mul(hw));
            const f = p1.sub(norm.mul(hw));

            try self.emit(a, pc);
            try self.emit(b, pc);
            try self.emit(e, pc);
            try self.emit(e, pc);
            try self.emit(b, pc);
            try self.emit(f, pc);
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

        fn strokeClosed(self: Self, points: []const V2, style: DrawStyle) !void {
            if (points.len < 2) return;

            const sc = packWithOpacity(style.stroke.?, style.opacity);
            const hw = self.hw;
            const start = self.batch.mark();

            const n = points.len;
            for (0..n) |i| {
                const p0 = points[i];
                const p1 = points[(i + 1) % n];

                try self.emitSegment(p0, p1, sc, hw);
            }
            try self.batch.pushCall(
                self.tri_key,
                start,
                self.batch.mark() - start,
            );
        }

        fn strokeOpen(self: Self, points: []const V2, style: DrawStyle) !void {
            if (points.len < 2) return;

            const sc = packWithOpacity(style.stroke.?, style.opacity);
            const hw = self.hw;
            const start = self.batch.mark();

            const n = points.len - 1;
            for (0..n) |i| {
                const p0 = points[i];
                const p1 = points[i + 1];

                try self.emitSegment(p0, p1, sc, hw);
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
            if (style.fill == null and style.stroke == null) return;

            const bucket = bucketFor(c.radius, self.px_per_unit);
            const num_steps = seg_buckets[bucket];
            const ring = unit_rings[bucket];

            var pts: [MAX_SEG]V2 = undefined;
            for (0..num_steps) |i| {
                pts[i] = c.origin.add(ring[i].mul(c.radius));
            }
            const perimeter = pts[0..num_steps];

            if (style.fill) |fc| {
                const col = packWithOpacity(fc, style.opacity);
                const start = self.batch.mark();
                for (0..num_steps) |i| {
                    try self.emit(c.origin, col);
                    try self.emit(perimeter[i], col);
                    try self.emit(perimeter[(i + 1) % num_steps], col);
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
            if (style.fill == null and style.stroke == null) return;

            const bucket = bucketFor(@max(e.semi_major, e.semi_minor), self.px_per_unit);
            const num_steps = seg_buckets[bucket];
            const ring = unit_rings[bucket];

            var pts: [MAX_SEG]V2 = undefined;
            for (0..num_steps) |i| {
                const u = ring[i];
                pts[i] = e.origin.add(.{ .x = u.x * e.semi_major, .y = u.y * e.semi_minor });
            }
            const perimeter = pts[0..num_steps];

            if (style.fill) |fc| {
                const col = packWithOpacity(fc, style.opacity);
                const start = self.batch.mark();
                for (0..num_steps) |i| {
                    try self.emit(e.origin, col);
                    try self.emit(perimeter[i], col);
                    try self.emit(perimeter[(i + 1) % num_steps], col);
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
            if (style.fill == null and style.stroke == null) return;

            if (a.thickness == 0) {

                // doing the wedge path
                const sweep = a.end_angle - a.start_angle;
                if (@abs(sweep) >= std.math.tau)
                    return self.circle(
                        .{ .origin = a.origin, .radius = a.radius },
                        style,
                    );

                var buf: [MAX_SEG + 1]V2 = undefined;
                buf[0] = a.origin;
                const seg_len = arcSegs(a.radius, sweep, self.px_per_unit);

                arcInto(buf[1..], a.origin, a.radius, a.start_angle, a.end_angle, seg_len);
                const len = seg_len + 1;
                const perimeter = buf[0..len];

                if (style.fill) |fc| {
                    const col = packWithOpacity(fc, style.opacity);

                    const start = self.batch.mark();
                    for (0..len) |i| {
                        try self.emit(buf[0], col);
                        try self.emit(buf[i], col);
                        try self.emit(buf[i + 1], col);
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
                // TODO:  do the donut ring
            }
        }

        fn capsule(self: Self, c: Shapes.Capsule, style: DrawStyle) !void {
            if (style.fill == null and style.stroke == null) return;
            const pi: f32 = std.math.pi;

            const horizontal = c.half_width >= c.half_height;

            const r = @min(c.half_width, c.half_height);
            const off = if (horizontal) c.half_width - r else c.half_height - r;
            const right_c = if (horizontal) c.center.add(.{ .x = off, .y = 0 }) else c.center.add(.{ .x = 0, .y = off });
            const left_c = if (horizontal) c.center.add(.{ .x = -off, .y = 0 }) else c.center.add(.{ .x = 0, .y = -off });
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

            if (style.fill) |fc| {
                const col = packWithOpacity(fc, style.opacity);

                const start = self.batch.mark();
                for (0..w) |i| {
                    try self.emit(c.center, col);
                    try self.emit(perimeter[i], col);
                    try self.emit(perimeter[@mod((i + 1), w)], col);
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
            if (style.stroke) |_| {
                try self.strokeOpen(
                    &.{ l.start, l.end },
                    style,
                );
            }
        }

        fn polyline(self: Self, l: Shapes.PolyLine, style: DrawStyle) !void {
            if (style.stroke) |_| {
                try self.strokeOpen(
                    l.points,
                    style,
                );
            }
        }

        fn poly(self: Self, p: Shapes.Polygon, style: DrawStyle) !void {
            if (style.fill) |fc| {
                const cache = p.triangle_cache orelse return error.InvalidPolygon;
                const col = packWithOpacity(fc, style.opacity);
                const start = self.batch.mark();
                for (cache) |t| {
                    try self.emit(t[0], col);
                    try self.emit(t[1], col);
                    try self.emit(t[2], col);
                }
                try self.batch.pushCall(self.tri_key, start, self.batch.mark() - start);
            }
            if (style.stroke) |_| {
                try self.strokeClosed(p.points, style);
            }
        }

        fn nGon(self: Self, g: Shapes.NGon, style: DrawStyle) !void {
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

            if (style.fill) |fc| {
                const col = packWithOpacity(fc, style.opacity);
                const start = self.batch.mark();

                for (0..n) |i| {
                    try self.emit(g.origin, col);
                    try self.emit(points[i], col);
                    try self.emit(points[@mod((i + 1), n)], col);
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
            const n = std.math.clamp(s.points, 2, MAX_SEG / 2);
            const total = 2 * n;
            const step = std.math.tau / @as(f32, @floatFromInt(total));

            var points: [MAX_SEG]V2 = undefined;
            for (0..total) |i| {
                const r = if (i & 1 == 0) s.outer_radius else s.inner_radius;
                const fi: f32 = @floatFromInt(i);
                const point = s.origin.add(.{
                    .x = @cos(fi * step),
                    .y = @sin(fi * step),
                });
                points[i] = point.mul(r);
            }

            if (style.fill) |fc| {
                const col = packWithOpacity(fc, style.opacity);
                const start = self.batch.mark();

                for (0..total) |i| {
                    try self.emit(s.origin, col);
                    try self.emit(points[i], col);
                    try self.emit(points[@mod((i + 1), total)], col);
                }

                try self.batch.pushCall(
                    self.tri_key,
                    start,
                    self.batch.mark() - start,
                );
            }

            if (style.stroke) |_| {
                try self.strokeClosed(points[0..total], style);
            }
        }

        fn rect(self: Self, r: Shapes.Rectangle, style: DrawStyle) !void {
            const corners = r.getCorners();
            if (style.fill) |fc| {
                const col = packWithOpacity(fc, style.opacity);
                const start = self.batch.mark();

                try self.emit(corners[0], col);
                try self.emit(corners[1], col);
                try self.emit(corners[2], col);
                try self.emit(corners[0], col);
                try self.emit(corners[2], col);
                try self.emit(corners[3], col);

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
            _ = self;
            _ = r;
            _ = style;
        }

        fn tri(self: Self, t: Shapes.Triangle, style: DrawStyle) !void {
            if (style.fill) |fc| {
                const col = packWithOpacity(fc, style.opacity);
                const start = self.batch.mark();

                try self.emit(t.v0, col);
                try self.emit(t.v1, col);
                try self.emit(t.v2, col);

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
    comptime makeVertex: fn ([2]f32, u32) V,
    tri_key: K,
    shape: ShapeData,
    xf: LocalXform,
    style: DrawStyle,
    map: ClipMap,
    hw: f32,
    px_per_unit: f32,
) !void {
    const ts = Tess(V, K){
        .batch = batch,
        .makeVertex = makeVertex,
        .xf = xf,
        .map = map,
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

fn arcSegs(radius: f32, sweep: f32, px_per_unit: f32) usize {
    const bucket = bucketFor(radius, px_per_unit);
    const full_len = @as(f32, @floatFromInt(seg_buckets[bucket]));

    return @as(
        usize,
        @intFromFloat(
            @max(2, @ceil(full_len * @abs(sweep) / std.math.tau)),
        ),
    );
}

fn arcInto(buf: []V2, center: V2, radius: f32, start: f32, end: f32, n: usize) void {
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

fn packWithOpacity(c: Color, opacity: f32) u32 {
    if (opacity >= 1.0) return c.pack();

    var rgba = c.rgba;
    rgba.a = @intFromFloat(
        @round(@as(f32, rgba.a) * std.math.clamp(opacity, 0, 1)),
    );

    return rgba.pack();
}
