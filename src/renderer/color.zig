// Color module public interface
// This re-exports all color functionality for external use

const color = @import("color/Color.zig");
const library = @import("color/library.zig");

// Core Color struct
pub const Color = color.Color;

// Pre-defined color constants (1000+ colors)
pub const Colors = library;

// Color math (conversions, distance, lerp, hue shift)
pub const math = @import("color/math.zig");

// Type classifications (Hue, Tone, Saturation, Temperature, TaggedColor)
pub const types = @import("color/types.zig");

// Future exports (as they are implemented):
// pub const query = @import("color/query.zig");
// pub const palette = @import("color/palette.zig");
// pub const generators = @import("color/generators.zig");
