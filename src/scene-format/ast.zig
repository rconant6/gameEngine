const std = @import("std");
const Allocator = std.mem.Allocator;
const tok = @import("token.zig");
pub const Token = tok.Token;
pub const SourceLocation = tok.SourceLocation;

pub const SceneFile = struct {
    decls: []Declaration,
    source_file_name: []const u8,

    pub fn deinit(self: *SceneFile, gpa: Allocator) void {
        for (self.decls) |*decl| {
            decl.deinit(gpa);
        }
        gpa.free(self.decls);
        gpa.free(self.source_file_name);
    }
};

pub const Declaration = union(enum) {
    scene: SceneDeclaration,
    entity: EntityDeclaration,
    asset: AssetDeclaration,
    component: ComponentDeclaration,
    template: TemplateDeclaration,

    pub fn deinit(self: *Declaration, gpa: Allocator) void {
        switch (self.*) {
            .scene => |*s| s.deinit(gpa),
            .entity => |*e| e.deinit(gpa),
            .asset => |*a| a.deinit(gpa),
            .component => |*c| c.deinit(gpa),
            .template => |*t| t.deinit(gpa),
        }
    }
};

pub const TemplateDeclaration = struct {
    name: []const u8,
    components: []ComponentDeclaration,
    location: SourceLocation,

    pub fn deinit(self: *TemplateDeclaration, gpa: Allocator) void {
        for (self.components) |*comp| {
            comp.deinit(gpa);
        }
        gpa.free(self.name);
        gpa.free(self.components);
    }
};

pub const SceneDeclaration = struct {
    name: []const u8,
    decls: []Declaration,
    is_container: bool,
    location: SourceLocation,

    pub fn deinit(self: *SceneDeclaration, gpa: Allocator) void {
        gpa.free(self.name);
        for (self.decls) |*decl| {
            decl.deinit(gpa);
        }
        gpa.free(self.decls);
    }
};
pub const EntityDeclaration = struct {
    name: []const u8,
    components: []ComponentDeclaration,
    location: SourceLocation,

    pub fn deinit(self: *EntityDeclaration, gpa: Allocator) void {
        gpa.free(self.name);
        for (self.components) |*comp| {
            comp.deinit(gpa);
        }
        gpa.free(self.components);
    }
};
pub const AssetDeclaration = struct {
    name: []const u8,
    asset_type: AssetType,
    properties: ?[]Property,
    location: SourceLocation,

    pub fn deinit(self: *AssetDeclaration, gpa: Allocator) void {
        gpa.free(self.name);
        if (self.properties) |props| {
            for (props) |*prop| {
                prop.deinit(gpa);
            }
            gpa.free(props);
        }
    }
};
pub const ComponentDeclaration = union(enum) {
    generic: GenericBlock,
    sprite: SpriteBlock,
    collider: SpriteBlock,

    pub fn deinit(self: *ComponentDeclaration, gpa: Allocator) void {
        _ = gpa;
        switch (self.*) {
            inline else => |*block| {
                block.deinit();
            },
        }
    }
};
pub const GenericBlock = struct {
    name: []const u8,
    properties: ?[]Property,
    location: SourceLocation,
    nested_blocks: ?[]GenericBlock,
    gpa: Allocator,

    pub fn deinit(self: *GenericBlock) void {
        if (self.properties) |props| {
            for (props) |*prop| {
                prop.deinit(self.gpa);
            }
            self.gpa.free(props);
        }
        if (self.nested_blocks) |blocks| {
            for (blocks) |*block| {
                block.deinit();
            }
            self.gpa.free(blocks);
        }
        self.gpa.free(self.name);
    }
};
pub const SpriteBlock = struct {
    name: []const u8,
    shape_type: []const u8,
    properties: ?[]Property,
    location: SourceLocation,
    gpa: Allocator,

    pub fn deinit(self: *SpriteBlock) void {
        if (self.properties) |props| {
            for (props) |*prop| {
                prop.deinit(self.gpa);
            }
            self.gpa.free(props);
        }
        self.gpa.free(self.name);
        self.gpa.free(self.shape_type);
    }
};

pub const Property = struct {
    name: []const u8,
    type_annotation: TypeAnnotation,
    value: Value,
    location: SourceLocation,

    pub fn deinit(self: *Property, gpa: Allocator) void {
        gpa.free(self.name);
        self.value.deinit(gpa);
    }
};

pub const TypeAnnotation = struct {
    base_type: BaseType,
    is_array: bool,
};

pub const AssetType = enum {
    font,
    zxl,
    // TODO(asset-types): Add when engine implements:
    // audio,     // Sound effects and music
    // shader,    // Custom shader programs
    // material,  // Material/appearance data
    // mesh,      // 3D model data (future 3D support)
    // NOTE: Lexer will need to have added to keywords

    pub fn fromString(str: []const u8) ?AssetType {
        if (std.mem.eql(u8, str, "font")) return .font;
        if (std.mem.eql(u8, str, "zxl")) return .zxl;
        return null;
    }

    pub fn toString(self: AssetType) []const u8 {
        return switch (self) {
            .font => "font",
            .zxl => "zxl",
        };
    }
};

pub const BaseType = enum {
    vec2,
    vec3,
    f32,
    i32,
    u32,
    bool,
    string,
    color,
    asset,
    // custom, // TODO: this is coming later
};

pub const Value = union(enum) {
    number: f64,
    string: []const u8,
    color: u32,
    boolean: bool,
    vector: []f64,
    assetRef: []const u8,
    array: []Value,

    pub fn deinit(self: *Value, gpa: Allocator) void {
        switch (self.*) {
            .string => |s| gpa.free(s),
            .vector => |v| gpa.free(v),
            .assetRef => |a| gpa.free(a),
            .array => |arr| {
                for (arr) |*val| {
                    val.deinit(gpa);
                }
                gpa.free(arr);
            },
            .number, .color, .boolean => {},
        }
    }
};
