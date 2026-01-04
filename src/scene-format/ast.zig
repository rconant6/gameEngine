const std = @import("std");
const Allocator = std.mem.Allocator;
const tok = @import("token.zig");
pub const Token = tok.Token;
pub const SourceLocation = tok.SourceLocation;

pub const SceneFile = struct {
    decls: []Declaration,
    source_file_name: []const u8,

    pub fn deinit(self: *SceneFile, allocator: Allocator) void {
        for (self.decls) |*decl| {
            decl.deinit(allocator);
        }
        allocator.free(self.decls);
    }
};

pub const Declaration = union(enum) {
    scene: SceneDeclaration,
    entity: EntityDeclaration,
    asset: AssetDeclaration,
    component: ComponentDeclaration,

    pub fn deinit(self: *Declaration, allocator: Allocator) void {
        switch (self.*) {
            .scene => |*s| s.deinit(allocator),
            .entity => |*e| e.deinit(allocator),
            .asset => |*a| a.deinit(allocator),
            .component => |*c| c.deinit(allocator),
        }
    }
};

pub const SceneDeclaration = struct {
    name: []const u8,
    decls: []Declaration,
    is_container: bool,
    location: SourceLocation,

    pub fn deinit(self: *SceneDeclaration, allocator: Allocator) void {
        allocator.free(self.name);
        for (self.decls) |*decl| {
            decl.deinit(allocator);
        }
        allocator.free(self.decls);
    }
};
pub const EntityDeclaration = struct {
    name: []const u8,
    components: []ComponentDeclaration,
    location: SourceLocation,

    pub fn deinit(self: *EntityDeclaration, allocator: Allocator) void {
        allocator.free(self.name);
        for (self.components) |*comp| {
            comp.deinit(allocator);
        }
        allocator.free(self.components);
    }
};
pub const AssetDeclaration = struct {
    name: []const u8,
    asset_type: AssetType,
    properties: []Property,
    location: SourceLocation,

    pub fn deinit(self: *AssetDeclaration, allocator: Allocator) void {
        allocator.free(self.name);
        for (self.properties) |*prop| {
            prop.deinit(allocator);
        }
        allocator.free(self.properties);
    }
};
pub const ComponentDeclaration = union(enum) {
    generic: GenericBlock,
    sprite: SpriteBlock,
    collider: SpriteBlock,

    pub fn deinit(self: *ComponentDeclaration, allocator: Allocator) void {
        switch (self.*) {
            inline else => |block| {
                allocator.free(block.name);
                for (block.properties) |*prop| {
                    prop.deinit(allocator);
                }
                allocator.free(block.properties);

                if (@TypeOf(block) == SpriteBlock)
                    allocator.free(block.shape_type);
            },
        }
    }
};
pub const GenericBlock = struct {
    name: []const u8,
    properties: []Property,
    location: SourceLocation,
};
pub const SpriteBlock = struct {
    name: []const u8,
    shape_type: []const u8,
    properties: []Property,
    location: SourceLocation,
};

pub const Property = struct {
    name: []const u8,
    type_annotation: TypeAnnotation,
    value: Value,
    location: SourceLocation,

    pub fn deinit(self: *Property, allocator: Allocator) void {
        allocator.free(self.name);
        self.value.deinit(allocator);
    }
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

    pub fn deinit(self: *Value, allocator: Allocator) void {
        switch (self.*) {
            .string => |s| allocator.free(s),
            .vector => |v| allocator.free(v),
            .assetRef => |a| allocator.free(a),
            .array => |arr| {
                for (arr) |*val| {
                    val.deinit(allocator);
                }
                allocator.free(arr);
            },
            .number, .color, .boolean => {},
        }
    }
};
