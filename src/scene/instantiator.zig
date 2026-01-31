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
const math = @import("math");
const V2 = math.V2;
const WorldPoint = math.WorldPoint;
const ScreenPoint = math.ScreenPoint;
const ComponentRegistry = @import("ecs").ComponentRegistry;
const ShapeRegistry = @import("renderer").ShapeRegistry;
const ColliderRegistry = @import("ecs").ColliderRegistry;
const Shapes = @import("renderer").Shapes;

const ecs = @import("ecs");
const World = ecs.World;
const Entity = ecs.Entity;
const Components = ecs.comps;

const asset = @import("assets");
const Font = asset.Font;
const FontHandle = asset.FontHandle;
const AssetManager = asset.AssetManager;

const rend = @import("renderer");
const Color = rend.Color;
const Colors = rend.Colors;
const CoordinateSpace = rend.CoordinateSpace;
const ScreenAnchor = rend.ScreenAnchor;

const acts = @import("action");
const Action = acts.Action;
const ActionTarget = acts.ActionTarget;
const ActionType = acts.ActionType;
const InputTrigger = acts.InputTrigger;
const CollisionTrigger = acts.CollisionTrigger;

pub const InstantiatorError = error{
    ShapeBuilding,
    InvalidValue,
    MissingAssetPath,
    MissingRequiredField,
    NotOptionalValue,
    UnableToFindFont,
    UnableToLoadFont,
    UnknownComponent,
    UnknownProperty,

    ActionTargetTypeMismatch,
    ArrayTypeMismatch,
    BoolTypeMismatch,
    ColorTypeMismatch,
    EnumTypeMismatch,
    FloatTypeMismatch,
    FontHandleTypeMismatch,
    IntTypeMismatch,
    KeyCodeTypeMismatch,
    MouseButtonTypeMismatch,
    OptionalTypeMismatch,
    PointerTypeMismatch,
    ScreenAnchorMismatch,
    StringTypeMismatch,
    TypeMismatch,
    V2ITypeMismatch,
    V2TypeMismatch,

    Unimplemented,
    UnimplementedAction,
    UnimplementedTopLevel,
};

pub const Instantiator = struct {
    allocator: Allocator,
    last_instantiated_entities: std.ArrayList(Entity),
    world: *World,
    assets: *AssetManager,
    in_screen_space: bool = false,

    pub fn init(allocator: Allocator, world: *World, assets: *AssetManager) Instantiator {
        return .{
            .allocator = allocator,
            .last_instantiated_entities = .empty,
            .world = world,
            .assets = assets,
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
    ) !void {
        self.last_instantiated_entities.clearRetainingCapacity();

        return for (scene_file.decls) |*decl| {
            switch (decl.*) {
                .scene => |*scene_decl| {
                    try self.instantiateScene(scene_decl);
                },
                .asset => |*asset_decl| try self.instantiateAsset(
                    asset_decl,
                ),
                .entity => |*entity_decl| try self.instantiateEntity(
                    entity_decl,
                ),
                .template => return error.TEMPLEATE,
                else => {
                    // NOTE: .component cannot be at top level
                },
            }
        };
    }

    pub fn instantiateScene(
        self: *Instantiator,
        scene: *const scene_format.SceneDeclaration,
    ) !void {
        for (scene.decls) |*decl| {
            switch (decl.*) {
                .entity => |*entity_decl| {
                    try self.instantiateEntity(entity_decl);
                },
                .scene => |*nested_scene| {
                    try self.instantiateScene(nested_scene);
                },
                .asset => |*nested_asset| {
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
        const entity = try self.world.createEntity();
        try self.last_instantiated_entities.append(self.allocator, entity);

        for (entity_decl.components) |comp_decl| {
            switch (comp_decl) {
                inline else => |comp| {
                    if (std.mem.eql(u8, comp.name, "UIElement")) {
                        self.in_screen_space = true;
                        break;
                    }
                },
            }
        }
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
                self.instantiateFont(asset_decl) catch {
                    return InstantiatorError.UnableToLoadFont;
                };
            },
        };
    }

    fn instantiateFont(
        self: *Instantiator,
        asset_decl: *const AssetDeclaration,
    ) !void {
        const props = asset_decl.properties orelse return;
        const handle = if (getProperty(props, "abs_path")) |prop| blk: {
            const abs_path_value = try self.extractValueForType(
                []const u8,
                prop.value,
            ) orelse
                return InstantiatorError.NotOptionalValue;
            break :blk try self.assets.loadFontFromPath(abs_path_value);
        } else if (getProperty(props, "filename")) |f| blk: {
            const file = try self.extractValueForType(
                []const u8,
                f.value,
            ) orelse
                return InstantiatorError.NotOptionalValue;
            if (getProperty(props, "path")) |p| {
                const path = try self.extractValueForType(
                    []const u8,
                    p.value,
                ) orelse
                    return InstantiatorError.NotOptionalValue;

                const full = try std.fs.path.join(self.allocator, &.{ path, file });
                defer self.allocator.free(full);
                break :blk try self.assets.loadFontFromPath(full);
            } else {
                if (self.assets.fonts.font_path.len < 0)
                    return InstantiatorError.MissingAssetPath;
                break :blk try self.assets.loadFont(file);
            }
        } else {
            return InstantiatorError.MissingAssetPath;
        };

        const gop = try self.assets.name_to_font.getOrPut(asset_decl.name);
        if (!gop.found_existing) {
            const owned_name = try self.allocator.dupe(u8, asset_decl.name);
            gop.key_ptr.* = owned_name;
            gop.value_ptr.* = handle;
        }
    }

    // MARK: Components
    pub fn addComponent(
        self: *Instantiator,
        entity: Entity,
        comp_decl: *const ComponentDeclaration,
    ) !void {
        const comp_name = switch (comp_decl.*) {
            .generic => |g| g.name,
            .sprite => |s| s.name,
            .collider => |c| c.name,
        };

        if (std.mem.eql(u8, comp_name, "OnCollision")) {
            const component = try self.buildTriggerComponent(Components.OnCollision, CollisionTrigger, comp_decl.generic);
            errdefer {
                for (component.triggers) |trigger| {
                    self.allocator.free(trigger.other_tag_pattern);
                }
            }
            try self.world.addComponent(entity, Components.OnCollision, component);
            return;
        }
        if (std.mem.eql(u8, comp_name, "OnInput")) {
            const component = try self.buildTriggerComponent(Components.OnInput, InputTrigger, comp_decl.generic);
            try self.world.addComponent(entity, Components.OnInput, component);
            return;
        }

        switch (comp_decl.*) {
            .collider => |c| {
                const shape_index = ColliderRegistry.getColliderIndex(c.shape_type) orelse
                    return InstantiatorError.UnknownComponent;
                inline for (ColliderRegistry.shape_names, 0..) |_, i| {
                    if (shape_index == i) {
                        const ShapeType = ColliderRegistry.shape_types[i];
                        const collider = try self.buildColliderComponent(ShapeType, c);
                        try self.world.addComponent(entity, Components.Collider, collider);
                        return;
                    }
                }
            },
            .sprite => |s| {
                defer self.in_screen_space = false;
                const coord_space: CoordinateSpace = if (self.in_screen_space) .ScreenSpace else .WorldSpace;
                const shape_index = ShapeRegistry.getShapeIndex(s.shape_type, coord_space) orelse
                    return InstantiatorError.UnknownComponent;
                inline for (ShapeRegistry.shape_names, 0..) |_, i| {
                    if (shape_index == i) {
                        const ShapeType = ShapeRegistry.shape_types[i];
                        const sprite = try self.buildSpriteComponent(
                            ShapeType,
                            s,
                        );
                        try self.world.addComponent(entity, Components.Sprite, sprite);
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
                        );
                        try self.world.addComponent(entity, ComponentType, component);
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
        var component: ComponentType = getDefaultValue(ComponentType);

        if (comp.properties) |props| {
            for (props) |prop| {
                var field_found = false;

                inline for (std.meta.fields(ComponentType)) |field| {
                    if (std.mem.eql(u8, field.name, prop.name)) {
                        field_found = true;

                        const field_value = try self.extractValueForType(
                            field.type,
                            prop.value,
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
    ) !Components.Sprite {
        if (ShapeType == Shapes.Polygon(WorldPoint) or ShapeType == Shapes.Polygon(ScreenPoint)) {
            return try self.buildPolygonSprite(sprite);
        }
        if (ShapeType == Shapes.Ellipse(WorldPoint) or ShapeType == Shapes.Ellipse(ScreenPoint)) {
            return InstantiatorError.Unimplemented;
        }

        var component = std.mem.zeroInit(Components.Sprite, .{});
        var shape = std.mem.zeroInit(ShapeType, .{});

        // For screen space shapes, geometry should be centered at (0,0)
        // and positioning comes from the entity's UIElement component
        const is_screen_space = self.in_screen_space;

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
                            // Skip setting center/origin for screen space shapes
                            // These should always be (0,0) for screen space
                            if (is_screen_space and
                                (std.mem.eql(u8, shape_field.name, "center") or
                                    std.mem.eql(u8, shape_field.name, "origin")))
                            {
                                field_found = true;
                                break;
                            }

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
        const polygon = try Shapes.Polygon(WorldPoint).init(self.allocator, owned_points);
        component.geometry = ShapeRegistry.createShapeUnion(Shapes.Polygon(WorldPoint), polygon);

        return component;
    }

    fn buildColliderComponent(
        self: *Instantiator,
        comptime ColliderShapeType: type,
        collider_block: SpriteBlock,
    ) !Components.Collider {
        var shape_data: ColliderShapeType = undefined;

        if (collider_block.properties) |props| {
            for (props) |prop| {
                inline for (std.meta.fields(ColliderShapeType)) |field| {
                    if (std.mem.eql(u8, field.name, prop.name)) {
                        const field_value = try self.extractValueForType(
                            field.type,
                            prop.value,
                        );
                        if (field_value) |val| {
                            @field(shape_data, field.name) = val;
                        }
                    }
                }
            }
        }

        const collider_data = ColliderRegistry.createColliderUnion(
            ColliderShapeType,
            shape_data,
        );
        return Components.Collider{
            .collider = collider_data,
        };
    }
    fn buildTriggerComponent(
        self: *Instantiator,
        comptime ComponentType: type,
        comptime TriggerType: type,
        comp: GenericBlock,
    ) !ComponentType {
        var triggers: std.ArrayList(TriggerType) = .empty;
        errdefer triggers.deinit(self.allocator);

        if (comp.nested_blocks) |blocks| {
            for (blocks) |*nested_block| {
                if (std.mem.eql(u8, nested_block.name, "trigger")) {
                    const trigger = try self.buildTrigger(TriggerType, nested_block.*);
                    try triggers.append(self.allocator, trigger);
                }
            }
        }

        return ComponentType{
            .triggers = try triggers.toOwnedSlice(self.allocator),
        };
    }

    fn buildTrigger(
        self: *Instantiator,
        comptime TriggerType: type,
        trigger_block: GenericBlock,
    ) !TriggerType {
        var trigger: TriggerType = undefined;

        if (trigger_block.properties) |props| {
            inline for (std.meta.fields(TriggerType)) |field| {
                if (std.mem.eql(u8, field.name, "actions")) {
                    // NOTE: skip the actions, will build at the end
                } else if (@typeInfo(field.type) == .@"union") {
                    var union_value: ?field.type = null;
                    inline for (std.meta.fields(field.type)) |union_field| {
                        if (getProperty(props, union_field.name)) |prop| {
                            const value = try self.extractValueForType(union_field.type, prop.value) orelse {
                                return InstantiatorError.MissingRequiredField;
                            };
                            union_value = @unionInit(field.type, union_field.name, value);
                            break;
                        }
                    }
                    if (union_value) |uv| {
                        @field(trigger, field.name) = uv;
                    } else {
                        return InstantiatorError.MissingRequiredField;
                    }
                } else {
                    if (getProperty(props, field.name)) |prop| {
                        const value = try self.extractValueForType(field.type, prop.value) orelse {
                            return InstantiatorError.MissingRequiredField;
                        };
                        @field(trigger, field.name) = value;
                    } else {
                        return InstantiatorError.MissingRequiredField;
                    }
                }
            }
        }

        var actions: std.ArrayList(Action) = .empty;
        errdefer actions.deinit(self.allocator);
        if (trigger_block.nested_blocks) |blocks| {
            for (blocks) |*nested_block| {
                if (std.mem.eql(u8, nested_block.name, "action")) {
                    const action = try self.buildAction(nested_block.*);
                    try actions.append(self.allocator, action);
                }
            }
        }

        trigger.actions = try actions.toOwnedSlice(self.allocator);
        return trigger;
    }

    fn buildAction(
        self: *Instantiator,
        action_block: GenericBlock,
    ) !Action {
        var priority: i32 = 0;
        var action_type: ?ActionType = null;

        if (action_block.properties) |props| {
            if (getProperty(props, "priority")) |priority_prop| {
                priority = try self.extractValueForType(i32, priority_prop.value) orelse 0;
            }
            const type_str = if (getProperty(props, "type")) |type_prop|
                try self.extractValueForType([]const u8, type_prop.value) orelse {
                    return InstantiatorError.MissingRequiredField;
                }
            else {
                return InstantiatorError.MissingRequiredField;
            };
            inline for (std.meta.fields(ActionType)) |field| {
                if (std.mem.eql(u8, type_str, field.name)) {
                    if (field.type == void) {
                        action_type = @unionInit(ActionType, field.name, {});
                    } else if (@typeInfo(field.type) == .@"struct") {
                        // Handle struct payloads spawn_entity, set_velocity...
                        var payload: field.type = undefined;
                        inline for (std.meta.fields(field.type)) |payload_field| {
                            const field_value = if (getProperty(
                                props,
                                payload_field.name,
                            )) |prop|
                                try self.extractValueForType(payload_field.type, prop.value)
                            else if (@typeInfo(payload_field.type) == .optional)
                                null
                            else
                                getDefaultValue(payload_field.type);

                            @field(payload, payload_field.name) = field_value orelse {
                                return InstantiatorError.MissingRequiredField;
                            };
                        }
                        action_type = @unionInit(ActionType, field.name, payload);
                    } else {
                        // Handle simple payloads of supported types
                        for (props) |prop| {
                            if (!std.mem.eql(u8, "type", prop.name) and
                                !std.mem.eql(u8, "priority", prop.name))
                            {
                                const value = try self.extractValueForType(field.type, prop.value) orelse {
                                    return InstantiatorError.MissingRequiredField;
                                };
                                action_type = @unionInit(ActionType, field.name, value);
                            }
                        }
                    }
                    break;
                }
            }
        }

        return Action{
            .action_type = action_type orelse {
                return InstantiatorError.UnknownProperty;
            },
            .priority = priority,
        };
    }

    fn extractValueForType(
        self: *Instantiator,
        comptime T: type,
        value: Value,
    ) !?T {
        switch (@typeInfo(T)) {
            .float => {
                // T is f32 or f64
                return switch (value) {
                    .number => |n| @floatCast(n),
                    else => InstantiatorError.FloatTypeMismatch,
                };
            },
            .int => {
                // T is i32, u8, u32...
                return switch (value) {
                    .number => |n| @intFromFloat(n),
                    else => InstantiatorError.IntTypeMismatch,
                };
            },
            .bool => {
                return switch (value) {
                    .boolean => |b| b,
                    else => InstantiatorError.BoolTypeMismatch,
                };
            },
            .pointer => |ptr_info| {
                // For []const u8 (strings)
                if (ptr_info.size == .slice and ptr_info.child == u8) {
                    return switch (value) {
                        .string => |s| s,
                        else => InstantiatorError.StringTypeMismatch,
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
                                        return InstantiatorError.ArrayTypeMismatch;
                                    },
                                }
                            }
                            break :blk points;
                        },
                        else => InstantiatorError.ArrayTypeMismatch,
                    };
                }
                return InstantiatorError.PointerTypeMismatch;
            },
            .@"struct" => {
                // For V2, V2I, Color, FontHandle...
                if (T == V2) {
                    return switch (value) {
                        .vector => |v| V2{
                            .x = @floatCast(v[0]),
                            .y = @floatCast(v[1]),
                        },
                        else => InstantiatorError.V2TypeMismatch,
                    };
                }
                if (T == math.V2I) {
                    return switch (value) {
                        .vector => |v| math.V2I{
                            .x = @intFromFloat(v[0]),
                            .y = @intFromFloat(v[1]),
                        },
                        else => InstantiatorError.V2ITypeMismatch,
                    };
                }
                if (T == Color) {
                    return switch (value) {
                        .color => |c| Color.initFromU32Hex(c),
                        else => InstantiatorError.ColorTypeMismatch,
                    };
                }
                if (T == FontHandle) {
                    return switch (value) {
                        .assetRef => |a| try self.assets.getFontAssetHandle(a),
                        else => InstantiatorError.FontHandleTypeMismatch,
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
                } else if (Child == ShapeRegistry.getShapeType(@typeName(o.child))) {
                    // TODO buildShape
                    return InstantiatorError.ShapeBuilding;
                }
                return InstantiatorError.OptionalTypeMismatch;
            },
            .@"enum" => {
                if (T == ActionTarget)
                    return getActionTarget(value.string) orelse
                        return InstantiatorError.ActionTargetTypeMismatch;
                if (T == KeyCode) {
                    return getKeyCode(value.string) orelse
                        return InstantiatorError.KeyCodeTypeMismatch;
                }
                if (T == MouseButton) {
                    return getMouseButton(value.string) orelse
                        return InstantiatorError.MouseButtonTypeMismatch;
                }
                if (T == ScreenAnchor) {
                    return getScreenAnchor(value.string) orelse
                        return InstantiatorError.ScreenAnchorMismatch;
                }
                return InstantiatorError.EnumTypeMismatch;
            },
            .@"union" => {
                return InstantiatorError.TypeMismatch;
            },
            else => return InstantiatorError.UnionTypeMismatch,
        }
        return InstantiatorError.TypeMismatch;
    }
};

fn getDefaultValue(comptime T: type) T {
    const type_info = @typeInfo(T);
    return switch (type_info) {
        .void => {},
        .int, .comptime_int => 0,
        .float, .comptime_float => 0.0,
        .bool => false,
        .optional => null,
        .pointer => |ptr_info| {
            if (ptr_info.size == .slice) {
                return &[_]std.meta.Child(T){};
            }
            @compileError("Cannot provide default for pointer type: " ++ @typeName(T));
        },
        .@"struct" => |struct_info| {
            var result: T = undefined;
            inline for (struct_info.fields) |field| {
                if (field.defaultValue()) |default_val| {
                    @field(result, field.name) = default_val;
                } else {
                    @field(result, field.name) = getDefaultValue(field.type);
                }
            }
            return result;
        },
        .@"enum" => |enum_info| {
            if (enum_info.fields.len > 0) {
                return @enumFromInt(enum_info.fields[0].value);
            }
            @compileError("Cannot provide default for empty enum: " ++ @typeName(T));
        },
        .@"union" => |union_info| {
            if (union_info.fields.len > 0) {
                const first_field = union_info.fields[0];
                const field_value = getDefaultValue(first_field.type);
                return @unionInit(T, first_field.name, field_value);
            }
            @compileError("Cannot provide default for empty union: " ++ @typeName(T));
        },
        else => @compileError("Cannot provide default value for type: " ++ @typeName(T)),
    };
}

fn getProperty(props: []const Property, property: []const u8) ?Property {
    for (props) |prop| {
        if (std.mem.eql(u8, prop.name, property)) return prop;
    }

    return null;
}

fn getKeyCode(key_str: []const u8) ?KeyCode {
    return std.meta.stringToEnum(KeyCode, key_str);
}
fn getMouseButton(button_str: []const u8) ?MouseButton {
    return std.meta.stringToEnum(MouseButton, button_str);
}
fn getActionTarget(target: []const u8) ?ActionTarget {
    return std.meta.stringToEnum(ActionTarget, target);
}
fn getActionType(action: []const u8) ?ActionType {
    return std.meta.stringToEnum(ActionType, action);
}
fn getScreenAnchor(anchor: []const u8) ?ScreenAnchor {
    return std.meta.stringToEnum(ScreenAnchor, anchor);
}
