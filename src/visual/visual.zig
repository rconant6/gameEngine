//! visual — the vocabulary of a drawable thing. Description, never execution.
//!
//! Dep: math ONLY. Enforced by the build: `visual` is exempt from the debug
//! auto-injection in build.zig, because `debug` imports `renderer` and pulling
//! it in here would re-form the ecs -> renderer -> registry cycle this lib exists
//! to break.
//!
//! Membership test for anything added here: could a headless program that never
//! opens a window meaningfully use this? Color yes, Renderable yes, drawText no.

const math = @import("math");

// MARK: Color
const col = @import("color.zig");
pub const Color = col.Color;
pub const Colors = col.Colors;
pub const ColorLibrary = col.ColorLibrary;
pub const Hue = col.Hue;
pub const Temperature = col.Temperature;
pub const Saturation = col.Saturation;
pub const Tone = col.Tone;
pub const Family = col.Family;
pub const TaggedColor = col.TaggedColor;
pub const Generator = col.generators;
// Color's wire representations — packed RGBA8 and HSVA. They live in
// visual/color/ (a color format is not geometry) and surface here so consumers
// like the zxl pixel format can speak them without importing all of color.
pub const Rgba = col.math.Rgba;
pub const Hsva = col.math.Hsva;

// MARK: Geometry
// Imported as MODULES, not sibling files: `shapes` and `triangulation` are
// their own build modules (they predate this lib), and a file may belong to
// only one module. build.zig points those modules at src/visual/.
pub const Shapes = @import("shapes");
pub const triangulation = @import("triangulation");
const sd = @import("shape_data.zig");
pub const ShapeData = sd.ShapeData;
pub const ShapeRegistry = sd.ShapeRegistry;

// MARK: Description
const rt = @import("render_types.zig");
pub const CoordinateSpace = rt.CoordinateSpace;
pub const PixelFormat = rt.PixelFormat;
pub const DrawStyle = rt.DrawStyle;
pub const Gradient = rt.Gradient;
pub const Renderable = rt.Renderable;
pub const ScreenAnchor = rt.ScreenAnchor;
pub const Transform = rt.Transform;
pub const getAnchorPos = rt.getAnchorPosition;
