// Color module public interface
// This re-exports all color functionality for external use
const color = @import("color/Color.zig");
const library = @import("color/library.zig");
// Core Color struct
pub const Color = color.Color;
// Pre-defined color constants (1800+ colors)
pub const Colors = @import("color/Colors.zig");
pub const ColorLibrary = library.ColorLibrary;
// Color math (conversions, distance, lerp, hue shift)
pub const math = @import("color/math.zig");
// Type classifications (Hue, Tone, Saturation, Temperature, TaggedColor)
const types = @import("color/types.zig");
pub const Hue = types.Hue;
pub const Temperature = types.Temperature;
pub const Saturation = types.Saturation;
pub const Tone = types.Tone;
pub const Family = types.Family;
pub const TaggedColor = types.TaggedColor;

// Future exports (as they are implemented):
// pub const palette = @import("color/palette.zig");
// pub const generators = @import("color/generators.zig");
