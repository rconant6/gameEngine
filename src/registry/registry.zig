// Component Registry
const component_registry = @import("component_registry.zig");
pub const ComponentRegistry = component_registry.ComponentRegistry;
pub const ComponentData = component_registry.ComponentData;

// Collider Shape Registry
const collider_shape_registry = @import("collider_shape_registry.zig");
pub const ColliderRegistry = collider_shape_registry.ColliderRegistry;
pub const ColliderData = collider_shape_registry.ColliderData;
pub const ColliderShape = collider_shape_registry.ColliderShape;

// Shape Registry
const shape_registry = @import("shape_registry.zig");
pub const ShapeRegistry = shape_registry.ShapeRegistry;
pub const ShapeData = shape_registry.ShapeData;
pub const CoordinateSpace = shape_registry.CoordinateSpace;
