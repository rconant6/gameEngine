const std = @import("std");
const tok = @import("token.zig");
pub const Token = tok.Token;
pub const SourceLocation = tok.SourceLocation;

pub const SceneFile = struct {
    decls: []Declaration,
    source_file_name: []const u8,
};

pub const Declaration = union(enum) {
    scene: SceneDeclaration,
    entity: EntityDeclaration,
    asset: AssetDeclaration,
    component: ComponentDeclaration,
    shape: ShapeDeclaration,
};

pub const SceneDeclaration = struct {
    name: []const u8,
    decls: []Declaration,
    is_container: bool,
    location: SourceLocation,
};
pub const EntityDeclaration = struct {
    name: []const u8,
    components: []ComponentDeclaration,
    location: SourceLocation,
};
pub const AssetDeclaration = struct {
    name: []const u8,
    asset_type: AssetType,
    properties: []Property,
    location: SourceLocation,
};
pub const ComponentDeclaration = struct {
    name: []const u8,
    properties: []Property,
    location: SourceLocation,
};
pub const ShapeDeclaration = struct {
    name: []const u8,
    properties: []Property,
    location: SourceLocation,
};

pub const ShapeBlock = struct {
    name: []const u8,
    properties: []Property,
    location: SourceLocation,
};

pub const Property = struct {
    name: []const u8,
    type_annotation: TypeAnnotation,
    value: Value,
    location: SourceLocation,
};

pub const TypeAnnotation = struct {
    base_type: BaseType,
    is_array: bool,
};

pub const AssetType = enum {
    font,
    // TODO(asset-types): Add when engine implements:
    // texture,   // 2D images for sprites
    // audio,     // Sound effects and music
    // shader,    // Custom shader programs
    // sprite,    // Sprite sheet definitions
    // material,  // Material/appearance data
    // mesh,      // 3D model data (future 3D support)};
    // NOTE: Lexer will need to have added to keywords

    pub fn fromString(str: []const u8) ?AssetType {
        if (std.mem.eql(u8, str, "font")) return .font;
        // TODO(asset-types): Add checks for new types here
        return null;
    }

    pub fn toString(self: AssetType) []const u8 {
        return switch (self) {
            .font => "font",
            // TODO(asset-types): Add cases for new types here
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
};
