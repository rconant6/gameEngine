//! The concern schema — the DSL's authored TYPE SYSTEM.
//!
//! This is the single source of truth that ingest resolves against and the LSP
//! validates against. It is DECOUPLED from the ECS: it describes what a noun can
//! *mean* (concerns + shape variants), never how the engine stores it. The
//! instantiator is the only thing that maps concerns → ECS components.
//!
//! Meta-model:
//!   - VARIANT : a reusable, self-contained field-set (circle, rectangle, mesh…),
//!               tagged so concerns can accept a category of them.
//!   - CONCERN : flat fields + optionally a variant SLOT drawing from the shared
//!               variant pool. A variant can be reused by multiple concerns
//!               (a `circle` serves both `geometry` and `collision`).
//!
//! Comptime data for now. Fields inside concerns/variants are meant to be
//! massaged as the language grows; the meta-model (variant + concern + tags) is
//! the stable skeleton.

const std = @import("std");

pub const FieldType = enum {
    f32,
    i32,
    u32,
    bool,
    vec2,
    vec3,
    color,
    string,
    label_ref, // a reference to another node/asset by label
    // enums are declared inline via `enum_values` on the FieldSpec when needed
};

pub const Literal = union(enum) {
    none,
    f32: f64,
    boolean: bool,
    vec2: [2]f64,
    vec3: [3]f64,
    color: u32,
    string: []const u8,
    ident: []const u8, // e.g. a named color default like `magenta`
};

pub const FieldSpec = struct {
    name: []const u8,
    type: FieldType,
    required: bool = false,
    default: Literal = .none,
    placeholder: Literal = .none,
    enum_values: []const []const u8 = &.{},
};

pub const VariantTag = enum {
    shape, // 2D tessellatable shapes (circle, rect, polygon, …)
    mesh, // 3D / referenced geometry
    // add tags as new kinds appear; a variant may later carry several.
};

pub const Variant = struct {
    name: []const u8,
    tag: VariantTag,
    fields: []const FieldSpec,
};

pub const Concern = struct {
    name: []const u8,
    fields: []const FieldSpec = &.{},
    accepts: ?VariantTag = null,
};

pub const Schema = struct {
    variants: []const Variant,
    concerns: []const Concern,

    pub fn findVariant(s: Schema, name: []const u8) ?*const Variant {
        for (s.variants) |*v| if (std.mem.eql(u8, v.name, name)) return v;
        return null;
    }
    pub fn findConcern(s: Schema, name: []const u8) ?*const Concern {
        for (s.concerns) |*c| if (std.mem.eql(u8, c.name, name)) return c;
        return null;
    }
    pub fn ownerOfField(s: Schema, field: []const u8) ?*const Concern {
        for (s.concerns) |*c| {
            for (c.fields) |f| if (std.mem.eql(u8, f.name, field)) return c;
        }
        return null;
    }
    pub fn ownerOfFieldSpec(
        s: Schema,
        name: []const u8,
    ) ?struct { concern: *const Concern, spec: *const FieldSpec } {
        for (s.concerns) |*c| {
            for (c.fields) |*f| {
                if (std.mem.eql(u8, f.name, name))
                    return .{ .concern = c, .spec = f };
            }
        }

        return null;
    }

    pub fn variantHasField(v: *const Variant, name: []const u8) bool {
        for (v.fields) |field| {
            if (std.mem.eql(u8, name, field.name)) return true;
        }

        return false;
    }

    pub fn variantFieldSpec(v: *const Variant, name: []const u8) ?*const FieldSpec {
        for (v.fields) |*f| {
            if (std.mem.eql(u8, f.name, name)) return f;
        }

        return null;
    }

    pub fn flagConcern(flag: []const u8) ?[]const u8 {
        return flags.get(flag);
    }

    pub fn isContainerType(name: []const u8) bool {
        return containers.get(name) orelse false;
    }

    const containers = std.StaticStringMap(bool).initComptime(.{
        .{ "scene", true }, .{ "level", true },
        .{ "world", true }, .{ "entity", true },
    });

    pub fn renderLiteral(lit: Literal, buf: []u8) []const u8 {
        return switch (lit) {
            .f32 => |n| std.fmt.bufPrint(buf, "{d}", .{n}) catch {
                return "...";
            },
            .boolean => |b| if (b) "true" else "false",
            .vec2 => |v| std.fmt.bufPrint(buf, "({d}, {d})", .{
                v[0],
                v[1],
            }) catch {
                return "...";
            },
            .vec3 => |v| std.fmt.bufPrint(buf, "({d}, {d}, {d})", .{
                v[0],
                v[1],
                v[2],
            }) catch {
                return "...";
            },
            .color => |c| std.fmt.bufPrint(buf, "#{x:0>8}", .{c}) catch {
                return "...";
            },
            .string, .ident => |s| s,
            .none => "(unset)",
        };
    }
};

const flags = std.StaticStringMap([]const u8).initComptime(.{
    .{ "collides", "collision" },
    .{ "bounces", "collision" },
    .{ "moves", "motion" },
    .{ "expires", "lifetime" },
});

//MARK: Variant Pool
const circle = Variant{ .name = "circle", .tag = .shape, .fields = &.{
    .{ .name = "radius", .type = .f32, .required = true, .placeholder = .{ .f32 = 1.0 } },
    .{ .name = "origin", .type = .vec2, .default = .{ .vec2 = .{ 0, 0 } } },
} };

const rectangle = Variant{ .name = "rectangle", .tag = .shape, .fields = &.{
    .{ .name = "half_width", .type = .f32, .required = true, .placeholder = .{ .f32 = 1.0 } },
    .{ .name = "half_height", .type = .f32, .required = true, .placeholder = .{ .f32 = 1.0 } },
    .{ .name = "center", .type = .vec2, .default = .{ .vec2 = .{ 0, 0 } } },
} };

const ellipse = Variant{ .name = "ellipse", .tag = .shape, .fields = &.{
    .{ .name = "semi_major", .type = .f32, .required = true, .placeholder = .{ .f32 = 1.0 } },
    .{ .name = "semi_minor", .type = .f32, .required = true, .placeholder = .{ .f32 = 0.5 } },
    .{ .name = "origin", .type = .vec2, .default = .{ .vec2 = .{ 0, 0 } } },
} };

const ngon = Variant{ .name = "ngon", .tag = .shape, .fields = &.{
    .{ .name = "radius", .type = .f32, .required = true, .placeholder = .{ .f32 = 1.0 } },
    .{ .name = "sides", .type = .u32, .required = true, .placeholder = .{ .f32 = 5 } },
    .{ .name = "origin", .type = .vec2, .default = .{ .vec2 = .{ 0, 0 } } },
} };

const polygon = Variant{
    .name = "polygon",
    .tag = .shape,
    .fields = &.{
        .{ .name = "points", .type = .vec2, .required = true }, // vec2[] — array handled at value level
        .{ .name = "center", .type = .vec2, .default = .{ .vec2 = .{ 0, 0 } } },
    },
};

// The 3D/lego door: a geometry variant that's a REFERENCE, not owned geometry.
const mesh = Variant{ .name = "mesh", .tag = .mesh, .fields = &.{
    .{ .name = "ref", .type = .label_ref, .required = true },
} };

// MARK: Concerns
const placement = Concern{
    .name = "placement",
    .fields = &.{
        .{ .name = "position", .type = .vec2, .default = .{ .vec2 = .{ 0, 0 } } }, // vec3 door: massage later
        .{ .name = "rotation", .type = .f32, .default = .{ .f32 = 0 } },
        .{ .name = "scale", .type = .f32, .default = .{ .f32 = 1 } },
    },
};

// geometry: pure variant slot — no flat fields, just "which shape".
const geometry = Concern{ .name = "geometry", .accepts = .shape };

const appearance = Concern{ .name = "appearance", .fields = &.{
    .{ .name = "fill", .type = .color, .default = .{ .ident = "magenta" } },
    .{ .name = "stroke", .type = .color, .default = .none },
    .{ .name = "stroke_width", .type = .f32, .default = .{ .f32 = 1 } },
    .{ .name = "opacity", .type = .f32, .default = .{ .f32 = 1 } },
    .{ .name = "visible", .type = .bool, .default = .{ .boolean = true } },
} };

const motion = Concern{ .name = "motion", .fields = &.{
    .{ .name = "velocity", .type = .vec2, .default = .{ .vec2 = .{ 0, 0 } } },
    .{ .name = "angular", .type = .f32, .default = .{ .f32 = 0 } },
} };

// collision: a variant slot (its own shape, defaults to geometry's) + flat fields.
const collision = Concern{ .name = "collision", .accepts = .shape, .fields = &.{
    .{ .name = "solid", .type = .bool, .default = .{ .boolean = false } },
    .{ .name = "restitution", .type = .f32, .default = .{ .f32 = 1 } },
    .{ .name = "mass", .type = .f32, .default = .{ .f32 = 1 } },
} };

const identity = Concern{ .name = "identity", .fields = &.{
    .{ .name = "tag", .type = .string, .default = .none },
} };

const lifetime = Concern{
    .name = "lifetime",
    .fields = &.{
        .{ .name = "remaining", .type = .f32, .default = .none }, // present ⇒ it expires
    },
};

const text = Concern{
    .name = "text",
    .fields = &.{
        .{ .name = "string", .type = .string, .default = .{ .string = "" } },
        .{ .name = "size", .type = .f32, .default = .{ .f32 = 1 } },
        .{ .name = "color", .type = .color, .default = .{ .ident = "magenta" } },
        .{ .name = "font", .type = .label_ref, .default = .none }, // references a font asset
    },
};

const view = Concern{
    .name = "view",
    .fields = &.{
        .{ .name = "anchor", .type = .string, .default = .none }, // screen anchor — enum later
        .{ .name = "offset", .type = .vec2, .default = .{ .vec2 = .{ 0, 0 } } },
    },
};

pub const schema = Schema{
    .variants = &.{ circle, rectangle, ellipse, ngon, polygon, mesh },
    .concerns = &.{
        placement, geometry, appearance, motion,
        collision, identity, lifetime,   text,
        view,
    },
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
const testing = std.testing;

test "schema: the 9 core concerns are present" {
    try testing.expectEqual(@as(usize, 9), schema.concerns.len);
    for ([_][]const u8{
        "placement", "geometry", "appearance", "motion",
        "collision", "identity", "lifetime",   "text",
        "view",
    }) |name| {
        try testing.expect(schema.findConcern(name) != null);
    }
}

test "schema: geometry is a pure variant slot accepting shapes" {
    const g = schema.findConcern("geometry").?;
    try testing.expectEqual(@as(usize, 0), g.fields.len); // no flat fields
    try testing.expectEqual(VariantTag.shape, g.accepts.?);
}

test "schema: a variant is shared by geometry and collision (same pool)" {
    // both concerns accept .shape → circle serves both
    try testing.expectEqual(VariantTag.shape, schema.findConcern("geometry").?.accepts.?);
    try testing.expectEqual(VariantTag.shape, schema.findConcern("collision").?.accepts.?);
    const c = schema.findVariant("circle").?;
    try testing.expectEqual(VariantTag.shape, c.tag);
}

test "schema: circle's radius is required with a visible placeholder" {
    const c = schema.findVariant("circle").?;
    var found = false;
    for (c.fields) |f| {
        if (std.mem.eql(u8, f.name, "radius")) {
            found = true;
            try testing.expect(f.required);
            try testing.expect(f.placeholder != .none);
        }
    }
    try testing.expect(found);
}

test "schema: origin defaults to zero (optional geometry field)" {
    const c = schema.findVariant("circle").?;
    for (c.fields) |f| {
        if (std.mem.eql(u8, f.name, "origin")) {
            try testing.expect(!f.required);
            try testing.expect(f.default == .vec2);
        }
    }
}

test "schema: mesh variant is the 3D/lego door — a label_ref" {
    const m = schema.findVariant("mesh").?;
    try testing.expectEqual(VariantTag.mesh, m.tag);
    try testing.expectEqual(FieldType.label_ref, m.fields[0].type);
}

test "schema: ownerOfField routes a flat field to its concern" {
    try testing.expectEqualStrings("appearance", schema.ownerOfField("fill").?.name);
    try testing.expectEqualStrings("motion", schema.ownerOfField("velocity").?.name);
    try testing.expectEqual(@as(?*const Concern, null), schema.ownerOfField("nonexistent"));
}
