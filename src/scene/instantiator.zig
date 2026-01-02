const std = @import("std");
const Allocator = std.mem.Allocator;
const scene_format = @import("scene-format");
const SceneFile = scene_format.SceneFile;
const EntityDeclaration = scene_format.EntityDeclaration;
const ComponentDeclaration = scene_format.ComponentDeclaration;
const AssetDeclaration = scene_format.AssetDeclaration;
const ShapeDeclaration = scene_format.ShapeDeclaration;
const SpriteBlock = scene_format.SpriteBlock;
const GenericBlock = scene_format.GenericBlock;

const Property = scene_format.Property;
const Value = scene_format.Value;
const BaseType = scene_format.BaseType;

const core = @import("core");
const V2 = core.V2;

const ComponentRegistry = @import("component_registry").ComponentRegistry;
const ShapeRegistry = @import("shape_registry").ShapeRegistry;

// Import Engine type - no circular dependency because engine doesn't import scene modules
const engine = @import("engine");
const Engine = engine.Engine;

const ecs = @import("entity");
const World = ecs.World;
const Entity = ecs.Entity;
const Components = ecs.comps;

const asset = @import("asset");
const Font = asset.Font;
const FontHandle = asset.FontHandle;

const rend = @import("renderer");
const Color = rend.Color;
const Colors = rend.Colors;
const Shape = rend.Shape;
const core_shapes = rend.cs;

pub const InstantiatorError = error{
    UnknownComponent,
    UnknownProperty,
    TypeMismatch,
    MissingRequiredField,
    InvalidValue,
    UnableToFindFont,
    UnableToLoadFont,
    Unimplemented,
    MissingAssetPath,
    NotOptionalValue,
};

pub const Instantiator = struct {
    allocator: Allocator,
    engine: *Engine,

    pub fn init(allocator: Allocator, game_engine: *Engine) Instantiator {
        return .{
            .allocator = allocator,
            .engine = game_engine,
        };
    }

    pub fn instantiate(self: *Instantiator, scene_file: *const SceneFile) !void {
        for (scene_file.decls) |*decl| {
            switch (decl.*) {
                .scene => |*scene_decl| {
                    std.debug.print("\n=== Scene: {s} ===\n", .{scene_decl.name});
                    try self.instantiateScene(scene_decl);
                },
                .asset => |*asset_decl| {
                    std.debug.print("== Asset: {s} ==\n", .{asset_decl.name});
                    self.instantiateAsset(asset_decl) catch |err| {
                        std.log.err(
                            "Asset Instantiation Failed {s}: {t} -> {any}",
                            .{ asset_decl.name, asset_decl.asset_type, err },
                        );
                        continue;
                    };
                },
                .entity => |*entity_decl| {
                    std.debug.print("== Entity: {s} ==\n", .{entity_decl.name});
                    self.instantiateEntity(entity_decl) catch |err| {
                        std.log.err(
                            "Entity Instantiation Failed {s}: with {d} components -> {any}",
                            .{ entity_decl.name, entity_decl.components.len, err },
                        );
                        continue;
                    };
                },
                else => {
                    // NOTE: .component cannot be at top level
                },
            }
        }
    }

    pub fn instantiateScene(
        self: *Instantiator,
        scene: *const scene_format.SceneDeclaration,
    ) !void {
        for (scene.decls) |*decl| {
            switch (decl.*) {
                .entity => |*entity_decl| {
                    std.debug.print("== Nested Entity: {s} ==\n", .{entity_decl.name});
                    _ = try self.instantiateEntity(entity_decl);
                },
                .scene => |*nested_scene| {
                    std.debug.print("== Nested Scene: {s} ==\n", .{nested_scene.name});
                    try self.instantiateScene(nested_scene);
                },
                .asset => |*nested_asset| {
                    std.debug.print("== Nested asset {s} ==\n", .{nested_asset.name});
                    try self.instantiateAsset(nested_asset);
                },
                else => {
                    // NOTE: .component cannot be at top level
                },
            }
        }
    }

    pub fn instantiateEntity(
        self: *Instantiator,
        entity_decl: *const EntityDeclaration,
    ) !void {
        const entity = try self.engine.world.createEntity();

        for (entity_decl.components) |*comp_decl| {
            try self.addComponent(entity, comp_decl);
        }
    }

    // MARK: Assets
    pub fn instantiateAsset(
        self: *Instantiator,
        asset_decl: *const AssetDeclaration,
    ) !void {
        const asset_type = asset_decl.asset_type;
        return switch (asset_type) {
            .font => {
                self.instantiateFont(asset_decl) catch |err| {
                    std.log.err("Unable to load font {s}  -> {}", .{ asset_decl.name, err });
                    return InstantiatorError.UnableToLoadFont;
                };
            },
        };
    }

    fn instantiateFont(self: *Instantiator, asset_decl: *const AssetDeclaration) !void {
        const props = asset_decl.properties;
        const handle = if (getProperty(props, "abs_path")) |prop| blk: {
            const abs_path_value = try self.extractValueForType([]const u8, prop.value) orelse
                return InstantiatorError.NotOptionalValue;
            break :blk try self.engine.assets.loadFontFromPath(abs_path_value);
        } else if (getProperty(props, "filename")) |f| blk: {
            const file = try self.extractValueForType([]const u8, f.value) orelse
                return InstantiatorError.NotOptionalValue;
            if (getProperty(props, "path")) |p| {
                const path = try self.extractValueForType([]const u8, p.value) orelse
                    return InstantiatorError.NotOptionalValue;

                const full = try std.fs.path.join(self.allocator, &.{ path, file });
                defer self.allocator.free(full);
                break :blk try self.engine.assets.loadFontFromPath(full);
            } else {
                if (self.engine.assets.fonts.font_path.len < 0)
                    return InstantiatorError.MissingAssetPath;
                break :blk try self.engine.assets.loadFont(file);
            }
        } else {
            return InstantiatorError.MissingAssetPath;
        };

        try self.engine.assets.registerFontAsset(asset_decl.name, handle);
    }

    // MARK: Components
    fn addComponent(
        self: *Instantiator,
        entity: Entity,
        comp_decl: *const ComponentDeclaration,
    ) !void {
        const comp_name = switch (comp_decl.*) {
            .generic => |g| g.name,
            .sprite => |s| s.name,
        };

        switch (comp_decl.*) {
            .sprite => |s| {
                const shape_index = ShapeRegistry.getShapeIndex(s.shape_type) orelse {
                    std.log.warn("Unknown component: {s}", .{comp_name});
                    return InstantiatorError.UnknownComponent;
                };
                inline for (ShapeRegistry.shape_names, 0..) |_, i| {
                    if (shape_index == i) {
                        const ShapeType = ShapeRegistry.shape_types[i];
                        const sprite = try self.buildSpriteComponent(ShapeType, s);
                        try self.engine.world.addComponent(entity, Components.Sprite, sprite);
                        return;
                    }
                }
            },
            .generic => |g| {
                const comp_index = ComponentRegistry.getComponentIndex(comp_name) orelse {
                    std.log.warn("Unknown component: {s}", .{comp_name});
                    return InstantiatorError.UnknownComponent;
                };
                inline for (ComponentRegistry.component_names, 0..) |_, i| {
                    if (comp_index == i) {
                        const ComponentType = ComponentRegistry.component_types[i];
                        const component = try self.buildGenericComponent(ComponentType, g);
                        try self.engine.world.addComponent(entity, ComponentType, component);
                        return;
                    }
                }
            },
        }
    }
    fn buildGenericComponent(
        self: *Instantiator,
        comptime ComponentType: type,
        comp: GenericBlock,
    ) !ComponentType {
        var component: ComponentType = std.mem.zeroInit(ComponentType, .{});

        for (comp.properties) |prop| {
            var field_found = false;
            inline for (std.meta.fields(ComponentType)) |field| {
                if (std.mem.eql(u8, field.name, prop.name)) {
                    field_found = true;
                    const field_value = self.extractValueForType(field.type, prop.value) catch |err| {
                        std.log.debug("{s} {s}", .{ field.name, @typeName(field.type) });
                        return err;
                    };
                    if (field_value) |val|
                        @field(component, field.name) = val;
                    break;
                }
            }
            if (!field_found) {
                std.log.err(
                    "[{s}] Unknown property: {s}\n",
                    .{ comp.name, prop.name },
                );
                return InstantiatorError.UnknownProperty;
            }
        }

        return component;
    }

    fn buildSpriteComponent(
        self: *Instantiator,
        comptime ShapeType: type,
        sprite: SpriteBlock,
    ) !Components.Sprite {
        if (ShapeType == core_shapes.Polygon) {
            return try self.buildPolygonSprite(sprite);
        }
        if (ShapeType == core_shapes.Ellipse) {
            std.log.err("Shape type {s} not yet supported in scene files\n", .{
                @typeName(ShapeType),
            });
            return InstantiatorError.Unimplemented;
        }

        var component = std.mem.zeroInit(Components.Sprite, .{});
        var shape = std.mem.zeroInit(ShapeType, .{});

        for (sprite.properties) |prop| {
            var field_found = false;

            // NOTE: this handles non-shape related fields (colors etc.)
            inline for (std.meta.fields(Components.Sprite)) |field| {
                if (std.mem.eql(u8, field.name, prop.name)) {
                    field_found = true;
                    const field_value = try self.extractValueForType(
                        field.type,
                        prop.value,
                    );
                    if (field_value) |val| {
                        @field(component, field.name) = val;
                    }
                    break;
                }
            }
            // NOTE: shape's fields are mixed in with sprite's in .scene files
            if (!field_found) {
                inline for (std.meta.fields(ShapeType)) |shape_field| {
                    if (std.mem.eql(u8, shape_field.name, prop.name)) {
                        field_found = true;
                        const field_value = try self.extractValueForType(
                            shape_field.type,
                            prop.value,
                        );
                        if (field_value) |val| {
                            @field(shape, shape_field.name) = val;
                        }
                        break;
                    }
                }
            }

            if (!field_found) {
                std.log.err(
                    "[{s}] Unknown property: {s}\n",
                    .{ sprite.name, prop.name },
                );
                return InstantiatorError.UnknownProperty;
            }
        }
        component.geometry = ShapeRegistry.createShapeUnion(ShapeType, shape);

        return component;
    }
    fn buildPolygonSprite(self: *Instantiator, sprite: SpriteBlock) !Components.Sprite {
        var component = std.mem.zeroInit(Components.Sprite, .{});
        var owned_points: []const V2 = undefined;
        defer self.allocator.free(owned_points);

        for (sprite.properties) |prop| {
            if (std.mem.eql(u8, "points", prop.name)) {
                owned_points = self.extractValueForType([]const V2, prop.value) catch |err|
                    {
                        std.log.err("Unable to create polygon points -> {any}", .{err});
                        return InstantiatorError.InvalidValue;
                    } orelse return InstantiatorError.InvalidValue;
                continue;
            }
            var field_found = false;
            inline for (std.meta.fields(Components.Sprite)) |field| {
                if (std.mem.eql(u8, field.name, prop.name)) {
                    field_found = true;
                    const field_value = try self.extractValueForType(
                        field.type,
                        prop.value,
                    );
                    if (field_value) |val| {
                        @field(component, field.name) = val;
                    }
                    break;
                }
            }
            if (!field_found) {
                std.log.err(
                    "[{s}] Unknown property: {s}\n",
                    .{ sprite.name, prop.name },
                );
                return InstantiatorError.UnknownProperty;
            }
        }
        const polygon = core_shapes.Polygon.init(self.allocator, owned_points) catch |err| {
            std.log.err("Unable to create polygon -> {any}", .{err});
            return InstantiatorError.InvalidValue;
        };
        component.geometry = .{ .polygon = polygon };
        return component;
    }

    fn extractValueForType(self: *Instantiator, comptime T: type, value: Value) !?T {
        switch (@typeInfo(T)) {
            .float => {
                // T is f32 or f64
                return switch (value) {
                    .number => |n| @floatCast(n),
                    else => InstantiatorError.TypeMismatch,
                };
            },
            .int => {
                // T is i32, u8, u32...
                return switch (value) {
                    .number => |n| @intFromFloat(n),
                    else => InstantiatorError.TypeMismatch,
                };
            },
            .bool => {
                return switch (value) {
                    .boolean => |b| b,
                    else => InstantiatorError.TypeMismatch,
                };
            },
            .pointer => |ptr_info| {
                // For []const u8 (strings)
                if (ptr_info.size == .slice and ptr_info.child == u8) {
                    return switch (value) {
                        .string => |s| s,
                        else => InstantiatorError.TypeMismatch,
                    };
                }
                // For []const V2 (point arrays for polygons)
                if (ptr_info.size == .slice and ptr_info.child == V2) {
                    return switch (value) {
                        .array => |arr| blk: {
                            const points = try self.allocator.alloc(V2, arr.len);
                            for (arr, 0..) |val, i| {
                                switch (val) {
                                    .vector => |v| {
                                        points[i] = V2{
                                            .x = @floatCast(v[0]),
                                            .y = @floatCast(v[1]),
                                        };
                                    },
                                    else => {
                                        self.allocator.free(points);
                                        return InstantiatorError.TypeMismatch;
                                    },
                                }
                            }
                            break :blk points;
                        },
                        else => InstantiatorError.TypeMismatch,
                    };
                }
                return InstantiatorError.TypeMismatch;
            },
            .@"struct" => {
                // For V2, Color, FontHandle...
                if (T == V2) {
                    return switch (value) {
                        .vector => |v| V2{
                            .x = @floatCast(v[0]),
                            .y = @floatCast(v[1]),
                        },
                        else => InstantiatorError.TypeMismatch,
                    };
                }
                if (T == Color) {
                    return switch (value) {
                        .color => |c| Color.initFromU32Hex(c),
                        else => InstantiatorError.TypeMismatch,
                    };
                }
                if (T == FontHandle) {
                    return switch (value) {
                        .assetRef => |a| {
                            return self.engine.assets.getFontAssetHandle(a) catch |err| {
                                std.log.err(
                                    "Unable to find font: {s} -> {any}",
                                    .{ a, err },
                                );
                                return InstantiatorError.UnableToFindFont;
                            };
                        },
                        else => InstantiatorError.TypeMismatch,
                    };
                }
                return InstantiatorError.TypeMismatch;
            },
            .optional => |o| {
                const Child = o.child;
                if (Child == Color) {
                    return switch (value) {
                        .color => |c| Color.initFromU32Hex(c),
                        else => return null,
                    };
                } else if (Child == Shape) {
                    // TODO buildShape
                    return InstantiatorError.Unimplemented;
                }
                return InstantiatorError.TypeMismatch;
            },
            else => return InstantiatorError.TypeMismatch,
        }
    }
};

fn getProperty(props: []const Property, property: []const u8) ?Property {
    for (props) |prop| {
        if (std.mem.eql(u8, prop.name, property)) return prop;
    }

    return null;
}
