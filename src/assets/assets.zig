const font = @import("font/font.zig");
pub const Font = font.Font;
const fd = @import("font/font_data.zig");
pub const FilteredGlyph = fd.FilteredGlyph;
pub const fa = @import("font/font_atlas.zig");
pub const GlyphEntry = fa.GlyphEntry;
pub const GlyphAtlas = fa.GlyphAtlas;
pub const glyph_builder = @import("font/glyph_builder.zig");
pub const sdf = @import("font/sdf.zig");
const font_manager = @import("font/font_manager.zig");
pub const FontManager = font_manager.FontManager;
pub const atlasTexture = font_manager.atlasTexture; // lazy R8 atlas texture for a *Font
pub const TextureManager = @import("textures/TextureManager.zig").TextureManager;
pub const TextureAsset = @import("textures/TextureManager.zig").TextureAsset;
pub const AssetManager = @import("AssetManager.zig");

// Embedded default font for tools that don't use the full AssetManager
pub const embedded_default_font = @embedFile("default_orbitron.ttf");
