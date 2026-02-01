// Color module public interface
// This re-exports all color functionality for external use

const color = @import("color/Color.zig");
const library = @import("color/library.zig");

// Core Color struct
pub const Color = color.Color;

// Pre-defined color constants (1000+ colors)
pub const Colors = library;

// Future exports (as they are implemented):
// pub const math = @import("color/math.zig");
// pub const types = @import("color/types.zig");
// pub const query = @import("color/query.zig");
// pub const palette = @import("color/palette.zig");
// pub const generators = @import("color/generators.zig");
