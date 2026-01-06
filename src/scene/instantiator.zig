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

const plat = @import("platform");
const KeyCode = plat.KeyCode;
const MouseButton = plat.MouseButton;

const Property = scene_format.Property;
const Value = scene_format.Value;
const BaseType = scene_format.BaseType;

const core = @import("core");
const V2 = core.V2;
const ComponentRegistry = core.ComponentRegistry;
const ShapeRegistry = core.ShapeRegistry;
const ColliderRegistry = core.ColliderRegistry;

const ecs = @import("entity");
const World = ecs.World;
const Entity = ecs.Entity;
const Components = ecs.comps;

const asset = @import("asset");
const Font = asset.Font;
const FontHandle = asset.FontHandle;
const AssetManager = asset.AssetManager;

const rend = @import("renderer");
const Color = rend.Color;
const Colors = rend.Colors;
const Shape = rend.Shape;
const core_shapes = rend.cs;

const acts = @import("action");
const ActionTarget = acts.ActionTarget;
const ActionType = acts.ActionType;
const CollisionTrigger = acts.CollisionTrigger;

pub const InstantiatorError = error{
    InvalidValue,
    MissingAssetPath,
    MissingRequiredField,
    NotOptionalValue,
    TypeMismatch,
    UnableToFindFont,
    UnableToLoadFont,
    Unimplemented,
    UnknownComponent,
    UnknownProperty,
};

pub const Instantiator = struct {
    allocator: Allocator,
    last_instantiated_entities: std.ArrayList(Entity),

    pub fn init(allocator: Allocator) Instantiator {
        return .{
            .allocator = allocator,
            .last_instantiated_entities = .empty,
        };
    }
    pub fn deinit(self: *Instantiator) void {
        self.last_instantiated_entities.deinit(self.allocator);
    }
    pub fn clearLastInstantiated(self: *Instantiator, world: *World) void {
        for (self.last_instantiated_entities.items) |entity_id| {
            world.destroyEntity(entity_id);
        }
        self.last_instantiated_entities.clearRetainingCapacity();
    }

    pub fn instantiate(
        self: *Instantiator,
        scene_file: *const SceneFile,
        world: *World,
        asset_manager: *AssetManager,
    ) !void {
        self.last_instantiated_entities.clearRetainingCapacity();

        for (scene_file.decls) |*decl| {
            switch (decl.*) {
                .scene => |*scene_decl| {
                    try self.instantiateScene(scene_decl, world, asset_manager);
                },
                .asset => |*asset_decl| try self.instantiateAsset(
                    asset_decl,
                    asset_manager,
                ),
                .entity => |*entity_decl| try self.instantiateEntity(
                    entity_decl,
                    world,
                    asset_manager,
                ),
                else => {
                    // NOTE: .component cannot be at top level
                },
            }
        }
    }

    pub fn instantiateScene(
        self: *Instantiator,
        scene: *const scene_format.SceneDeclaration,
        world: *World,
        asset_manager: *AssetManager,
    ) !void {
        for (scene.decls) |*decl| {
            switch (decl.*) {
                .entity => |*entity_decl| {
                    try self.instantiateEntity(entity_decl, world, asset_manager);
                },
                .scene => |*nested_scene| {
                    try self.instantiateScene(nested_scene, world, asset_manager);
                },
                .asset => |*nested_asset| {
                    try self.instantiateAsset(nested_asset, asset_manager);
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
        world: *World,
        asset_manager: *AssetManager,
    ) !void {
        const entity = try world.createEntity();
        try self.last_instantiated_entities.append(self.allocator, entity);

        for (entity_decl.components) |*comp_decl| {
            try self.addComponent(entity, world, asset_manager, comp_decl);
        }
    }

    // MARK: Assets
    pub fn instantiateAsset(
        self: *Instantiator,
        asset_decl: *const AssetDeclaration,
        asset_manager: *AssetManager,
    ) !void {
        const asset_type = asset_decl.asset_type;
        return switch (asset_type) {
            .font => {
                self.instantiateFont(asset_decl, asset_manager) catch {
                    return InstantiatorError.UnableToLoadFont;
                };
            },
        };
    }

    fn instantiateFont(
        self: *Instantiator,
        asset_decl: *const AssetDeclaration,
        asset_manager: *AssetManager,
    ) !void {
        const props = asset_decl.properties orelse return;
        const handle = if (getProperty(props, "abs_path")) |prop| blk: {
            const abs_path_value = try self.extractValueForType(
                []const u8,
                prop.value,
                asset_manager,
            ) orelse
                return InstantiatorError.NotOptionalValue;
            break :blk try asset_manager.loadFontFromPath(abs_path_value);
        } else if (getProperty(props, "filename")) |f| blk: {
            const file = try self.extractValueForType(
                []const u8,
                f.value,
                asset_manager,
            ) orelse
                return InstantiatorError.NotOptionalValue;
            if (getProperty(props, "path")) |p| {
                const path = try self.extractValueForType(
                    []const u8,
                    p.value,
                    asset_manager,
                ) orelse
                    return InstantiatorError.NotOptionalValue;

                const full = try std.fs.path.join(self.allocator, &.{ path, file });
                defer self.allocator.free(full);
                break :blk try asset_manager.loadFontFromPath(full);
            } else {
                if (asset_manager.fonts.font_path.len < 0)
                    return InstantiatorError.MissingAssetPath;
                break :blk try asset_manager.loadFont(file);
            }
        } else {
            return InstantiatorError.MissingAssetPath;
        };

        const gop = try asset_manager.name_to_font.getOrPut(asset_decl.name);
        if (!gop.found_existing) {
            const owned_name = try asset_manager.allocator.dupe(u8, asset_decl.name);
            gop.key_ptr.* = owned_name;
            gop.value_ptr.* = handle;
        }
    }

    // MARK: Components
    fn addComponent(
        self: *Instantiator,
        entity: Entity,
        world: *World,
        asset_manager: *AssetManager,
        comp_decl: *const ComponentDeclaration,
    ) !void {
        const comp_name = switch (comp_decl.*) {
            .generic => |g| g.name,
            .sprite => |s| s.name,
            .collider => |c| c.name,
        };

        switch (comp_decl.*) {
            .collider => |c| {
                const shape_index = ColliderRegistry.getShapeIndex(c.shape_type) orelse
                    return InstantiatorError.UnknownComponent;
                inline for (ColliderRegistry.shape_names, 0..) |_, i| {
                    if (shape_index == i) {
                        const ShapeType = ColliderRegistry.shape_types[i];
                        const collider = try self.buildColliderComponent(
                            ShapeType,
                            c,
                            asset_manager,
                        );
                        try world.addComponent(entity, Components.Collider, collider);
                        return;
                    }
                }
            },
            .sprite => |s| {
                const shape_index = ShapeRegistry.getShapeIndex(s.shape_type) orelse
                    return InstantiatorError.UnknownComponent;
                inline for (ShapeRegistry.shape_names, 0..) |_, i| {
                    if (shape_index == i) {
                        const ShapeType = ShapeRegistry.shape_types[i];
                        const sprite = try self.buildSpriteComponent(
                            ShapeType,
                            s,
                            asset_manager,
                        );
                        try world.addComponent(entity, Components.Sprite, sprite);
                        return;
                    }
                }
            },
            .generic => |g| {
                const comp_index = ComponentRegistry.getComponentIndex(comp_name) orelse
                    return InstantiatorError.UnknownComponent;
                inline for (ComponentRegistry.component_names, 0..) |_, i| {
                    if (comp_index == i) {
                        const ComponentType = ComponentRegistry.component_types[i];
                        const component = try self.buildGenericComponent(
                            ComponentType,
                            g,
                            asset_manager,
                        );
                        try world.addComponent(entity, ComponentType, component);
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
        asset_manager: *AssetManager,
    ) !ComponentType {
        var component: ComponentType = std.mem.zeroInit(ComponentType, .{});
        if (comp.properties) |props| {
            for (props) |prop| {
                var field_found = false;
                inline for (std.meta.fields(ComponentType)) |field| {
                    if (std.mem.eql(u8, field.name, prop.name)) {
                        field_found = true;
                        const field_value = try self.extractValueForType(
                            field.type,
                            prop.value,
                            asset_manager,
                        );
                        if (field_value) |val|
                            @field(component, field.name) = val;
                        break;
                    }
                }
                if (!field_found) {
                    return InstantiatorError.UnknownProperty;
                }
            }
        }

        return component;
    }

    fn buildSpriteComponent(
        self: *Instantiator,
        comptime ShapeType: type,
        sprite: SpriteBlock,
        asset_manager: *AssetManager,
    ) !Components.Sprite {
        if (ShapeType == core_shapes.Polygon) {
            return try self.buildPolygonSprite(sprite, asset_manager);
        }
        if (ShapeType == core_shapes.Ellipse) {
            return InstantiatorError.Unimplemented;
        }

        var component = std.mem.zeroInit(Components.Sprite, .{});
        var shape = std.mem.zeroInit(ShapeType, .{});
        if (sprite.properties) |props| {
            for (props) |prop| {
                var field_found = false;

                // NOTE: this handles non-shape related fields (colors etc.)
                inline for (std.meta.fields(Components.Sprite)) |field| {
                    if (std.mem.eql(u8, field.name, prop.name)) {
                        field_found = true;
                        const field_value = try self.extractValueForType(
                            field.type,
                            prop.value,
                            asset_manager,
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
                                asset_manager,
                            );
                            if (field_value) |val| {
                                @field(shape, shape_field.name) = val;
                            }
                            break;
                        }
                    }
                }

                if (!field_found) {
                    return InstantiatorError.UnknownProperty;
                }
            }
        }
        component.geometry = ShapeRegistry.createShapeUnion(ShapeType, shape);

        return component;
    }
    fn buildPolygonSprite(
        self: *Instantiator,
        sprite: SpriteBlock,
        asset_manager: *AssetManager,
    ) !Components.Sprite {
        var component = std.mem.zeroInit(Components.Sprite, .{});
        var owned_points: []const V2 = undefined;
        defer self.allocator.free(owned_points);
        if (sprite.properties) |props| {
            for (props) |prop| {
                if (std.mem.eql(u8, "points", prop.name)) {
                    owned_points = try self.extractValueForType(
                        []const V2,
                        prop.value,
                        asset_manager,
                    ) orelse return InstantiatorError.InvalidValue;
                    continue;
                }
                var field_found = false;
                inline for (std.meta.fields(Components.Sprite)) |field| {
                    if (std.mem.eql(u8, field.name, prop.name)) {
                        field_found = true;
                        const field_value = try self.extractValueForType(
                            field.type,
                            prop.value,
                            asset_manager,
                        );
                        if (field_value) |val| {
                            @field(component, field.name) = val;
                        }
                        break;
                    }
                }
                if (!field_found) {
                    return InstantiatorError.UnknownProperty;
                }
            }
        }
        const polygon = try core_shapes.Polygon.init(self.allocator, owned_points);
        component.geometry = .{ .polygon = polygon };
        return component;
    }

    fn buildColliderComponent(
        self: *Instantiator,
        comptime ColliderShapeType: type,
        collider_block: SpriteBlock,
        asset_manager: *AssetManager,
    ) !Components.Collider {
        var shape_data: ColliderShapeType = undefined;

        // Extract properties for the collider shape
        if (collider_block.properties) |props| {
            for (props) |prop| {
                inline for (std.meta.fields(ColliderShapeType)) |field| {
                    if (std.mem.eql(u8, field.name, prop.name)) {
                        const field_value = try self.extractValueForType(
                            field.type,
                            prop.value,
                            asset_manager,
                        );
                        if (field_value) |val| {
                            @field(shape_data, field.name) = val;
                        }
                    }
                }
            }
        }

        // Create the ColliderShape union based on the shape type
        const collider_shape = blk: {
            inline for (ColliderRegistry.shape_names, 0..) |name, i| {
                if (ColliderShapeType == ColliderRegistry.shape_types[i]) {
                    break :blk @unionInit(ecs.ColliderShape, name, shape_data);
                }
            }
            @compileError("Unknown collider shape type");
        };

        return Components.Collider{
            .shape = collider_shape,
        };
    }

    fn parseActionFromBlock(
        self: *Instantiator,
        block: GenericBlock,
        asset_manager: *AssetManager, // TODO: just give the instantiator an asset manger and world to stop passing this all over the place. Make API availble only from an instance that is made in Engine.init()
    ) !CollisionTrigger {
        // var action_type: ActionType = undefined;
        // use get property function (below)
        if (block.properties) |props| {
            for (props) |prop| {
                if (std.mem.eql(u8, "type", prop.name)) {
                    const action_type_str = try self.extractValueForType(
                        []const u8,
                        prop.value,
                        asset_manager,
                    ) orelse return InstantiatorError.InvalidValue;
                    _ = action_type_str;
                    continue;
                }
            }
        }
        return InstantiatorError.Unimplemented;
    }

    fn extractValueForType(
        self: *Instantiator,
        comptime T: type,
        value: Value,
        asset_manager: *AssetManager,
    ) !?T {
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
                        .assetRef => |a| try asset_manager.getFontAssetHandle(a),
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

fn getKeyCode(key_str: []const u8) !KeyCode {
    return std.meta.stringToEnum(KeyCode, key_str);
}
fn getMouseButton(button_str: []const u8) !MouseButton {
    return std.meta.stringToEnum(MouseButton, button_str);
}
fn getActionTarget(target: []const u8) !ActionTarget {
    return std.meta.stringToEnum(ActionTarget, target);
}
fn getActionType(action: []const u8) !ActionType {
    return std.meta.stringToEnum(ActionType, action);
}
