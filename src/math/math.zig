const std = @import("std");

pub const V2 = @import("V2.zig");
pub const V2I = @import("V2I.zig");
pub const V2U = @import("V2U.zig");

// World space is for gameplay - entities, physics, camera
// Screen space is for UI - menus, HUD, debug overlays
// Clip space is for GPU - internal rendering detail

// ui_element.screen_position = ScreenPoint{ .x = width - 100, .y = 20 }; // 100px from right, 20px from top
// ui_element.anchor = .TopRight;

// Example of an interaction with entities at mouse_world position
// const mouse_screen = input.getMousePosition(); // ScreenPoint
// const mouse_world = geometry_utils.screenToWorld(mouse_screen, camera, ctx); WorldPoint

//  entity.transform.position = WorldPoint{ .x = 0.0, .y = 50.0 }; World center, 50 units up
/// ----  WORLD SPACE ----
/// World Point: alias for V2{.x: f32, .y: f32}
///    Origin is {0, 0} 'center of the world'
///    X increases to the right
///    Y increases upwards
/// Scale is application defined (eg. +-100)
/// Use Cases:
///    Entity positions in the game world
///    Physics calculations
///    Gameplay logic
///    Camera positioning
pub const WorldPoint = V2;

/// ----  SCRENE SPACE ----
/// Screen Point: alias for V2I(.x: i32, .y: i32)
///     Origin is {0, 0} is top left of the screen
///     X increases to the right
///     Y increases downward
/// Limited by Window bounds (0..width, 0..height)
/// Use Cases:
///     UI elements, debug info, input coords
///     Fixed screen overlays, debug grids
///     Pixel Perfect Layout
pub const ScreenPoint = V2I;

/// ----   CLIP SPACE  ----
/// used for internal render pipeline by gpu
/// [2]f32
///     Origin is {0, 0} at the center
///     Bounds (-1..1) in both X and Y

pub const utils = @import("utils.zig");
