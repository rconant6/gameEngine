// Scene system - internal to engine
// Provides scene file loading, management, and entity instantiation

const manager_mod = @import("manager.zig");
pub const SceneManager = manager_mod.SceneManager;
pub const SceneManagerError = manager_mod.SceneManagerError;

const instantiator_mod = @import("instantiator.zig");
pub const Instantiator = instantiator_mod.Instantiator;
pub const InstantiatorError = instantiator_mod.InstantiatorError;

pub const loader = @import("loader.zig");

// Internal registries for scene loading
pub const ComponentRegistry = @import("component_registry.zig").ComponentRegistry;
pub const ShapeRegistry = @import("shape_registry.zig").ShapeRegistry;
