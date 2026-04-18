const font = @import("font/font.zig");
pub const Font = font.Font;
pub const AssetManager = @import("AssetManager.zig");
pub const TextureManager = @import("textures/TextureManager.zig").TextureManager;
pub const TextureAsset = @import("textures/TextureManager.zig").TextureAsset;
// Internal use only - used by renderer/text.zig
pub const FilteredGlyph = @import("font/font_data.zig").FilteredGlyph;
pub const glyph_builder = @import("font/glyph_builder.zig");

// Embedded default font for tools that don't use the full AssetManager
pub const embedded_default_font = @embedFile("default_orbitron.ttf");
