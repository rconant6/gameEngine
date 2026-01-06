pub const V2 = @import("V2.zig");
pub const V2I = @import("V2I.zig");
pub const V2U = @import("V2U.zig");

pub const GamePoint = V2;
pub const ScreenPoint = V2I;

pub const Input = @import("Input.zig");
pub const CollisionDetection = @import("CollisionDetection.zig");
pub const error_logger = @import("error_logger.zig");

pub const ComponentRegistry = @import("component_registry.zig").ComponentRegistry;
pub const ComponentData = @import("component_registry.zig").ComponentData;

pub const ShapeRegistry = @import("shape_registry.zig").ShapeRegistry;
pub const ShapeData = @import("shape_registry.zig").ShapeData;

pub const ColliderRegistry = @import("collider_shape_registry.zig").ColliderShapeRegistry;
pub const ColliderData = @import("collider_shape_registry.zig").ColliderData;
