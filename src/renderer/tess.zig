const std = @import("std");
const Allocator = std.mem.Allocator;
const cols = @import("color.zig");
const Color = cols.Color;
const math = @import("math");
const V2 = math.V2;
const RenderContext = @import("RenderContext.zig");
const gu = @import("geometry_utils.zig");
const Transform = gu.Transform;
const reg = @import("registry");
const ShapeData = reg.ShapeData;
const Shapes = @import("shapes.zig");
const Batch = @import("batch.zig").Batch;

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

pub const DrawStyle = struct {
    fill: ?Color = null,
    stroke: ?Color = null,
    stroke_width: f32 = 1.0, // world units world-side, px screen-side
};
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

        fn stroke(self: Self, edges: []const [2]V2, style: DrawStyle) !void {
            const sc = style.stroke.?.pack();
            const hw = self.hw;
            const start = self.batch.mark();

            for (edges) |edge| {
                const p0 = edge[0];
                const p1 = edge[1];

                const dir = p1.sub(p0).normalize();
                const norm = dir.perp();
                const a = p0.add(norm.mul(hw));
                const b = p0.sub(norm.mul(hw));
                const e = p1.add(norm.mul(hw));
                const f = p1.sub(norm.mul(hw));

                try self.emit(a, sc);
                try self.emit(b, sc);
                try self.emit(e, sc);
                try self.emit(e, sc);
                try self.emit(b, sc);
                try self.emit(f, sc);
            }
            try self.batch.pushCall(
                self.tri_key,
                start,
                self.batch.mark() - start,
            );
        }
        // NOTE: ring is an OPEN perimeter (first point NOT repeated at the end);
        // the last edge wraps back to ring[0] via `% n`. One int-mod per edge.
        fn strokeRing(self: Self, ring: []const V2, style: DrawStyle) !void {
            const sc = style.stroke.?.pack();
            const hw = self.hw;
            const start = self.batch.mark();

            const n = ring.len;
            for (0..n) |i| {
                const p0 = ring[i];
                const p1 = ring[(i + 1) % n];

                const dir = p1.sub(p0).normalize();
                const norm = dir.perp();
                const a = p0.add(norm.mul(hw));
                const b = p0.sub(norm.mul(hw));
                const e = p1.add(norm.mul(hw));
                const f = p1.sub(norm.mul(hw));

                try self.emit(a, sc);
                try self.emit(b, sc);
                try self.emit(e, sc);
                try self.emit(e, sc);
                try self.emit(b, sc);
                try self.emit(f, sc);
            }
            try self.batch.pushCall(
                self.tri_key,
                start,
                self.batch.mark() - start,
            );
        }

        fn circle(self: Self, c: Shapes.Circle(V2), style: DrawStyle) !void {
            if (style.fill == null and style.stroke == null) return;

            const num_steps: usize = 32; // update to be better than always 32
            const stepf: f32 = std.math.tau / @as(f32, @floatFromInt(num_steps));

            var pts: [num_steps]V2 = undefined;
            for (0..num_steps) |i| {
                const fi: f32 = @floatFromInt(i);
                const pnt: V2 = .{
                    .x = @cos(fi * stepf),
                    .y = @sin(fi * stepf),
                };
                pts[i] = c.origin.add(pnt.mul(c.radius));
            }

            if (style.fill) |fc| {
                const col = fc.pack();
                const start = self.batch.mark();
                for (0..num_steps) |i| {
                    try self.emit(c.origin, col);
                    try self.emit(pts[i], col);
                    try self.emit(pts[(i + 1) % num_steps], col);
                }
                try self.batch.pushCall(
                    self.tri_key,
                    start,
                    self.batch.mark() - start,
                );
            }

            if (style.stroke) |_| {
                try self.strokeRing(&pts, style);
            }
        }
        fn ellipse(self: Self, e: Shapes.Ellipse(V2), style: DrawStyle) !void {
            if (style.fill == null and style.stroke == null) return;

            const num_steps: usize = 32; // update to be better than always 32
            const stepf: f32 = std.math.tau / @as(f32, @floatFromInt(num_steps));

            var pts: [num_steps]V2 = undefined;
            for (0..num_steps) |i| {
                const fi: f32 = @floatFromInt(i);
                const x_step = e.semi_major * @cos(fi * stepf);
                const y_step = e.semi_minor * @sin(fi * stepf);
                pts[i] = e.origin.add(.{ .x = x_step, .y = y_step });
            }

            if (style.fill) |fc| {
                const col = fc.pack();
                const start = self.batch.mark();
                for (0..num_steps) |i| {
                    try self.emit(e.origin, col);
                    try self.emit(pts[i], col);
                    try self.emit(pts[(i + 1) % num_steps], col);
                }
                try self.batch.pushCall(
                    self.tri_key,
                    start,
                    self.batch.mark() - start,
                );
            }

            if (style.stroke) |_| {
                try self.strokeRing(&pts, style);
            }
        }
        fn line(self: Self, l: Shapes.Line(V2), style: DrawStyle) !void {
            if (style.stroke) |_| {
                try self.stroke(
                    &.{.{ l.start, l.end }},
                    style,
                );
            }
        }
        fn poly(self: Self, p: Shapes.Polygon(V2), style: DrawStyle) !void {
            if (style.fill) |fc| {
                const cache = p.triangle_cache orelse return error.InvalidPolygon;
                const c = fc.pack();
                const start = self.batch.mark();
                for (cache) |t| {
                    try self.emit(t[0], c);
                    try self.emit(t[1], c);
                    try self.emit(t[2], c);
                }
                try self.batch.pushCall(self.tri_key, start, self.batch.mark() - start);
            }
            if (style.stroke) |_| {
                try self.strokeRing(p.points, style);
            }
        }
        fn rect(self: Self, r: Shapes.Rectangle(V2), style: DrawStyle) !void {
            const corners = r.getCorners();
            if (style.fill) |fc| {
                const c = fc.pack();
                const start = self.batch.mark();

                try self.emit(corners[0], c);
                try self.emit(corners[1], c);
                try self.emit(corners[2], c);
                try self.emit(corners[0], c);
                try self.emit(corners[2], c);
                try self.emit(corners[3], c);

                try self.batch.pushCall(self.tri_key, start, self.batch.mark() - start);
            }
            if (style.stroke) |_| {
                try self.stroke(
                    &.{
                        .{ corners[0], corners[1] },
                        .{ corners[1], corners[2] },
                        .{ corners[2], corners[3] },
                        .{ corners[3], corners[0] },
                    },
                    style,
                );
            }
        }
        fn tri(self: Self, t: Shapes.Triangle(V2), style: DrawStyle) !void {
            if (style.fill) |fc| {
                const c = fc.pack();
                const start = self.batch.mark();

                try self.emit(t.v0, c);
                try self.emit(t.v1, c);
                try self.emit(t.v2, c);

                try self.batch.pushCall(self.tri_key, start, self.batch.mark() - start);
            }
            if (style.stroke) |_| {
                try self.stroke(
                    &.{
                        .{ t.v0, t.v1 },
                        .{ t.v1, t.v2 },
                        .{ t.v2, t.v0 },
                    },
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
    hw: f32, // stroke half-width, already resolved into the shape's space by caller
    px_per_unit: f32,
) !void {
    const t = Tess(V, K){
        .batch = batch,
        .makeVertex = makeVertex,
        .xf = xf,
        .map = map,
        .tri_key = tri_key,
        .hw = hw,
        .px_per_unit = px_per_unit,
    };

    // A3 fix (interim — Option A): one arm over the comptime-generated union.
    // Tags are suffixed World/Screen; strip the suffix to pick the base shape,
    // and coerce the shape's points to V2 (world passes through; screen is the
    // same {x,y} floats). The ClipMap for the space was already chosen by the
    // caller. NOTE: collapses to 6 V2-only variants in the follow-up step.
    // ScreenPoint == V2, so a shape over either point type is the SAME type — the
    // union variant `s` is already the V2-typed shape the methods want, no coercion.
    // The World/Screen suffix is still stripped to pick the method (variants are
    // named by point-space); the ClipMap for the space was chosen by the caller.
    switch (shape) {
        inline else => |s, tag| {
            const base = comptime stripSpaceSuffix(@tagName(tag));
            if (comptime std.mem.eql(u8, base, "Circle")) {
                try t.circle(s, style);
            } else if (comptime std.mem.eql(u8, base, "Ellipse")) {
                try t.ellipse(s, style);
            } else if (comptime std.mem.eql(u8, base, "Rectangle")) {
                try t.rect(s, style);
            } else if (comptime std.mem.eql(u8, base, "Triangle")) {
                try t.tri(s, style);
            } else if (comptime std.mem.eql(u8, base, "Polygon")) {
                try t.poly(s, style);
            } else if (comptime std.mem.eql(u8, base, "Line")) {
                try t.line(s, style);
            } else {
                @compileError("tessellate: unhandled shape base '" ++ base ++ "'");
            }
        },
    }
}

fn stripSpaceSuffix(comptime tag: []const u8) []const u8 {
    if (std.mem.endsWith(u8, tag, "World")) return tag[0 .. tag.len - 5];
    if (std.mem.endsWith(u8, tag, "Screen")) return tag[0 .. tag.len - 6];
    return tag;
}

// The caller uses this to pick fromScreen vs fromWorld before calling tessellate.
pub fn isScreenSpace(shape: ShapeData) bool {
    switch (shape) {
        inline else => |_, tag| {
            return comptime std.mem.endsWith(u8, @tagName(tag), "Screen");
        },
    }
}

