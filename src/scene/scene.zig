const std = @import("std");

const manager = @import("manager.zig");
pub const SceneManager = manager.SceneManager;
pub const SceneManagerError = manager.SceneManagerError;

const instantiator = @import("instantiator.zig");
pub const Instantiator = instantiator.Instantiator;
pub const InstantiatorError = instantiator.InstantiatorError;

pub const loader = @import("loader.zig");

const core = @import("math");
pub const ComponentRegistry = core.ComponentRegistry;
pub const ShapeRegistry = core.ShapeRegistry;

const templates = @import("templates.zig");
pub const Template = templates.Template;
pub const TemplateManager = templates.TemplateManager;
