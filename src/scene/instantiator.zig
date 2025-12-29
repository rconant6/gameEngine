const std = @import("std");
const Allocator = std.mem.Allocator;
const scene_format = @import("scene-format");
const SceneFile = scene_format.SceneFile;
const EntityDeclaration = scene_format.EntityDeclaration;
const ComponentDeclaration = scene_format.ComponentDeclaration;
const AssetDeclaration = scene_format.AssetDeclaration;
const ShapeDeclaration = scene_format.ShapeDeclaration;

const Property = scene_format.Property;
const Value = scene_format.Value;
const BaseType = scene_format.BaseType;

const core = @import("core");
const V2 = core.V2;

const engine = @import("engine");
const ComponentRegistry = engine.ComponentRegistry;
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
const Shape = rend.Shape;
const shapes = rend.shapes;

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
};

pub const Instantiator = struct {
    allocator: Allocator,
    engine: *engine.Engine,

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
                    self.instantiateEntity(entity_decl) catch {
                        std.log.info(
                            "Tried to instantiate an entity that failed",
                            .{},
                        );
                        continue;
                    };
                },
                else => {},
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
                else => {},
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
            const abs_path_value = try self.extractValueForType([]const u8, prop.value);
            break :blk try self.engine.assets.loadFontFromPath(abs_path_value);
        } else if (getProperty(props, "filename")) |f| blk: {
            const file = try self.extractValueForType([]const u8, f.value);
            if (getProperty(props, "path")) |p| {
                const path = try self.extractValueForType([]const u8, p.value);
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

        // Register scene name → handle
        try self.engine.assets.registerFontAsset(asset_decl.name, handle);
    }

    fn addComponent(
        self: *Instantiator,
        entity: Entity,
        comp_decl: *const ComponentDeclaration,
    ) !void {
        const comp_name = comp_decl.name;

        const comp_index = ComponentRegistry.getComponentIndex(comp_name) orelse {
            std.log.warn("Unknown component: {s}", .{comp_name});
            return InstantiatorError.UnknownComponent;
        };

        inline for (ComponentRegistry.component_names, 0..) |_, i| {
            if (comp_index == i) {
                const ComponentType = ComponentRegistry.component_types[i];
                const component = try self.buildComponent(ComponentType, comp_decl);
                try self.engine.world.addComponent(entity, ComponentType, component);
                return;
            }
        }
    }

    fn buildComponent(
        self: *Instantiator,
        comptime ComponentType: type,
        comp_decl: *const ComponentDeclaration,
    ) !ComponentType {
        if (ComponentType == Components.Sprite) {
            return self.buildSpriteComponent(comp_decl);
        } else {
            return self.buildGenericComponent(ComponentType, comp_decl);
        }
    }

    fn buildGenericComponent(
        self: *Instantiator,
        comptime ComponentType: type,
        comp_decl: *const ComponentDeclaration,
    ) !ComponentType {
        var component: ComponentType = std.mem.zeroInit(ComponentType, .{});

        const comp_name = comp_decl.name;

        // For each property in the scene
        for (comp_decl.properties) |prop| {
            var field_found = false;

            // Check against all fields in the component type
            inline for (std.meta.fields(ComponentType)) |field| {
                if (std.mem.eql(u8, field.name, prop.name)) {
                    field_found = true;
                    const field_value = self.extractValueForType(field.type, prop.value) catch |err| {
                        std.log.debug("{s} {s}", .{ field.name, @typeName(field.type) });
                        return err;
                    };
                    @field(component, field.name) = field_value;
                    break;
                }
            }

            if (!field_found) {
                std.log.err("[{s}] Unknown property: {s}\n", .{ comp_name, prop.name });
                return InstantiatorError.UnknownProperty;
            }
        }

        return component;
    }

    fn buildSpriteComponent(
        self: *Instantiator,
        comp_decl: *const ComponentDeclaration,
    ) !Components.Sprite {
        _ = self;
        _ = comp_decl;
        // TODO: Implement sprite component building
        // For now, return a default circle sprite
        return Components.Sprite{
            .geometry = .{ .circle = .{ .origin = .{ .x = 0, .y = 0 }, .radius = 1.0 } },
            .fill_color = null,
            .stroke_color = null,
            .stroke_width = 1.0,
            .visible = true,
        };
    }

    fn extractValueForType(self: *Instantiator, comptime T: type, value: Value) !T {
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
                return InstantiatorError.TypeMismatch;
            },
            .@"struct" => {
                // For V2, Color, FontHandle...
                if (T == V2) {
                    return switch (value) {
                        .vector => |v| V2{ .x = @floatCast(v[0]), .y = @floatCast(v[1]) },
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
            .optional => {
                return Color{ .a = 1, .r = 123, .b = 120, .g = 20 };
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
