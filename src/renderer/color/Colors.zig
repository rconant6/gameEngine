const Color = @import("Color.zig").Color;
// Backwards compatability (do not remove)
pub const RED = Color.initRgba(255, 0, 0, 255);
pub const DARK_RED = Color.initRgba(128, 0, 0, 255);
pub const LIGHT_RED = Color.initRgba(255, 179, 179, 255);
pub const GREEN = Color.initRgba(0, 255, 0, 255);
pub const DARK_GREEN = Color.initRgba(0, 128, 0, 255);
pub const LIGHT_GREEN = Color.initRgba(179, 255, 179, 255);
pub const BLUE = Color.initRgba(0, 0, 255, 255);
pub const DARK_BLUE = Color.initRgba(0, 0, 128, 255);
pub const LIGHT_BLUE = Color.initRgba(179, 179, 255, 255);
pub const CYAN = Color.initRgba(0, 255, 255, 255);
pub const MAGENTA = Color.initRgba(255, 0, 255, 255);
pub const YELLOW = Color.initRgba(255, 255, 0, 255);
pub const ORANGE = Color.initRgba(255, 128, 0, 255);
pub const DARK_ORANGE = Color.initRgba(255, 77, 0, 255);
pub const LIGHT_ORANGE = Color.initRgba(255, 204, 153, 255);
pub const PURPLE = Color.initRgba(128, 0, 128, 255);
pub const DARK_PURPLE = Color.initRgba(77, 0, 77, 255);
pub const LIGHT_PURPLE = Color.initRgba(204, 153, 204, 255);
pub const PINK = Color.initRgba(255, 191, 204, 255);
pub const BROWN = Color.initRgba(153, 102, 51, 255);
pub const LIME = Color.initRgba(191, 255, 0, 255);
pub const WHITE = Color.initRgba(255, 255, 255, 255);
pub const BLACK = Color.initRgba(0, 0, 0, 255);
pub const CLEAR = Color.initRgba(0, 0, 0, 0);
pub const LIGHT_GRAY = Color.initRgba(191, 191, 191, 255);
pub const GRAY = Color.initRgba(128, 128, 128, 255);
pub const DARK_GRAY = Color.initRgba(64, 64, 64, 255);

// BASIC COLORS
pub const BASIC_RED = Color.initRgba(255, 0, 0, 255);
pub const BASIC_DARK_RED = Color.initRgba(128, 0, 0, 255);
pub const BASIC_LIGHT_RED = Color.initRgba(255, 179, 179, 255);
pub const BASIC_GREEN = Color.initRgba(0, 255, 0, 255);
pub const BASIC_DARK_GREEN = Color.initRgba(0, 128, 0, 255);
pub const BASIC_LIGHT_GREEN = Color.initRgba(179, 255, 179, 255);
pub const BASIC_BLUE = Color.initRgba(0, 0, 255, 255);
pub const BASIC_DARK_BLUE = Color.initRgba(0, 0, 128, 255);
pub const BASIC_LIGHT_BLUE = Color.initRgba(179, 179, 255, 255);
pub const BASIC_CYAN = Color.initRgba(0, 255, 255, 255);
pub const BASIC_MAGENTA = Color.initRgba(255, 0, 255, 255);
pub const BASIC_YELLOW = Color.initRgba(255, 255, 0, 255);
// EXTENDED COLORS
pub const BASIC_ORANGE = Color.initRgba(255, 128, 0, 255);
pub const BASIC_DARK_ORANGE = Color.initRgba(255, 77, 0, 255);
pub const BASIC_LIGHT_ORANGE = Color.initRgba(255, 204, 153, 255);
pub const BASIC_PURPLE = Color.initRgba(128, 0, 128, 255);
pub const BASIC_DARK_PURPLE = Color.initRgba(77, 0, 77, 255);
pub const BASIC_LIGHT_PURPLE = Color.initRgba(204, 153, 204, 255);
pub const BASIC_PINK = Color.initRgba(255, 191, 204, 255);
pub const BASIC_BROWN = Color.initRgba(153, 102, 51, 255);
pub const BASIC_LIME = Color.initRgba(191, 255, 0, 255);
// NON-COLORS
pub const BASIC_WHITE = Color.initRgba(255, 255, 255, 255);
pub const BASIC_BLACK = Color.initRgba(0, 0, 0, 255);
pub const BASIC_CLEAR = Color.initRgba(0, 0, 0, 0);
pub const BASIC_LIGHT_GRAY = Color.initRgba(191, 191, 191, 255);
pub const BASIC_GRAY = Color.initRgba(128, 128, 128, 255);
pub const BASIC_DARK_GRAY = Color.initRgba(64, 64, 64, 255);
// NEONS
pub const NEON_RED = Color.initRgba(255, 26, 26, 255);
pub const NEON_GREEN = Color.initRgba(26, 255, 26, 255);
pub const NEON_BLUE = Color.initRgba(26, 26, 255, 255);
pub const NEON_CYAN = Color.initRgba(26, 255, 255, 255);
pub const NEON_MAGENTA = Color.initRgba(255, 26, 255, 255);
pub const NEON_YELLOW = Color.initRgba(255, 255, 26, 255);
pub const NEON_ORANGE = Color.initRgba(255, 102, 26, 255);
pub const NEON_PURPLE = Color.initRgba(204, 26, 255, 255);
pub const NEON_PINK = Color.initRgba(255, 26, 153, 255);
// PASTELS
pub const PASTEL_RED = Color.initRgba(255, 204, 204, 255);
pub const PASTEL_GREEN = Color.initRgba(204, 255, 204, 255);
pub const PASTEL_BLUE = Color.initRgba(204, 204, 255, 255);
pub const PASTEL_CYAN = Color.initRgba(204, 255, 255, 255);
pub const PASTEL_MAGENTA = Color.initRgba(255, 204, 255, 255);
pub const PASTEL_YELLOW = Color.initRgba(255, 255, 204, 255);
pub const PASTEL_ORANGE = Color.initRgba(255, 230, 204, 255);
pub const PASTEL_PURPLE = Color.initRgba(230, 204, 255, 255);
pub const PASTEL_PINK = Color.initRgba(255, 204, 230, 255);

// NATURE & EARTH (Essential for backgrounds/terrain)
pub const SKY_BLUE = Color.initRgba(135, 206, 235, 255);
pub const DEEP_OCEAN = Color.initRgba(0, 51, 102, 255);
pub const FOREST_GREEN = Color.initRgba(34, 139, 34, 255);
pub const OLIVE = Color.initRgba(107, 142, 35, 255);
pub const SAND = Color.initRgba(194, 178, 128, 255);
pub const DESERT_ORANGE = Color.initRgba(210, 105, 30, 255);
pub const TERRA_COTTA = Color.initRgba(226, 114, 91, 255);
pub const MUD = Color.initRgba(77, 51, 26, 255);

// METALLICS & UI (For that "Engine Tool" look)
pub const GOLD = Color.initRgba(255, 215, 0, 255);
pub const SILVER = Color.initRgba(192, 192, 192, 255);
pub const BRONZE = Color.initRgba(205, 127, 50, 255);
pub const STEEL = Color.initRgba(112, 128, 144, 255);
pub const SLATE = Color.initRgba(47, 79, 79, 255);
pub const GUNMETAL = Color.initRgba(42, 52, 57, 255);

// SKIN & ORGANIC (Great for testing blending/shading)
pub const PALE = Color.initRgba(255, 224, 189, 255);
pub const TAN = Color.initRgba(210, 180, 140, 255);
pub const COCOA = Color.initRgba(139, 69, 19, 255);
pub const MAROON = Color.initRgba(128, 0, 0, 255);

// NIGHT MODE (Deep, low-eye-strain tones)
pub const NIGHT_BLACK = Color.initRgba(13, 13, 15, 255);
pub const NIGHT_GRAY = Color.initRgba(28, 28, 32, 255);
pub const NIGHT_SLATE = Color.initRgba(45, 45, 54, 255);
pub const NIGHT_TEXT = Color.initRgba(169, 176, 194, 255);

// NIGHT ACCENTS (Muted neon-like highlights)
pub const MIDNIGHT_BLUE = Color.initRgba(25, 25, 112, 255);
pub const DEEP_PURPLE = Color.initRgba(48, 25, 52, 255);
pub const TOXIC_GREEN = Color.initRgba(0, 68, 27, 255);
pub const CRIMSON_DUSK = Color.initRgba(100, 10, 10, 255);

// VOID PALETTE (The PICO-8 "Secret" night colors)
pub const VOID_PURPLE = Color.initRgba(31, 0, 48, 255);
pub const VOID_TEAL = Color.initRgba(0, 31, 31, 255);
pub const VOID_OBSIDIAN = Color.initRgba(10, 10, 18, 255);

// VINTAGE / RETRO (The "PICO-8" style muted vibes)
pub const RETRO_BLUE = Color.initRgba(41, 173, 255, 255);
pub const RETRO_GREEN = Color.initRgba(0, 228, 54, 255);
pub const RETRO_PURPLE = Color.initRgba(131, 58, 255, 255);
pub const RETRO_YELLOW = Color.initRgba(255, 236, 39, 255);

// 1. THE "IRON & SLATE" FAMILY (Industrial/UI/Steel)
// Use these for toolbars, borders, and "heavy" engine objects
pub const SLATE_900 = Color.initRgba(15, 17, 26, 255);
pub const SLATE_700 = Color.initRgba(31, 35, 51, 255);
pub const SLATE_500 = Color.initRgba(71, 85, 122, 255);
pub const SLATE_300 = Color.initRgba(148, 163, 204, 255);
pub const SLATE_100 = Color.initRgba(219, 227, 248, 255);

// 2. THE "DESERT & DUST" FAMILY (Warm/Earthy/Organic)
// Great for testing terrain and "warm" lighting
pub const DUST_DARK = Color.initRgba(66, 40, 31, 255);
pub const DUST_MID = Color.initRgba(163, 103, 75, 255);
pub const DUST_LIGHT = Color.initRgba(224, 170, 117, 255);
pub const DUST_GOLD = Color.initRgba(245, 203, 92, 255);

// 3. THE "CYBER" FAMILY (High-Saturation/Neon)
// Use these for "Selection" states or FX
pub const CYBER_GRAPE = Color.initRgba(111, 22, 235, 255);
pub const CYBER_MELON = Color.initRgba(0, 255, 159, 255);
pub const CYBER_BANANA = Color.initRgba(255, 240, 31, 255);
pub const CYBER_GLITCH = Color.initRgba(255, 0, 110, 255);

// 4. THE "NORDIC" FAMILY (Cold/Desaturated/Clean)
// Good for "Night Mode" variants or Ice/Stone themes
pub const FROST_BLUE = Color.initRgba(143, 188, 219, 255);
pub const POLAR_NIGHT = Color.initRgba(46, 52, 64, 255);
pub const GLACIER_WHITE = Color.initRgba(236, 239, 244, 255);

// 5. THE "HUE-SHIFTED" SHADING RAMPS
// These demonstrate 'Hue Shifting': Shadows move toward Blue, Highlights toward Yellow
// This makes pixel art look "alive" rather than just "darker"

// RAMPS: DARK -> BASE -> LIGHT
pub const BERRY_SHADOW = Color.initRgba(74, 13, 56, 255);
pub const BERRY_BASE = Color.initRgba(190, 33, 55, 255);
pub const BERRY_LUME = Color.initRgba(255, 138, 148, 255);

pub const FOREST_SHADOW = Color.initRgba(13, 43, 46, 255);
pub const FOREST_BASE = Color.initRgba(38, 92, 66, 255);
pub const FOREST_LUME = Color.initRgba(163, 206, 39, 255);

// 1. THE "GAMEBOY / DMG" FAMILY (Retro Hardware Limits)
// Great for testing 2-bit (4-color) indexed logic in your custom format
pub const DMG_DARKEST = Color.initRgba(15, 56, 15, 255);
pub const DMG_DARK = Color.initRgba(48, 98, 48, 255);
pub const DMG_LIGHT = Color.initRgba(139, 172, 15, 255);
pub const DMG_LIGHTEST = Color.initRgba(155, 188, 15, 255);

// 2. THE "FLESH & BONE" FAMILY (Organic/Character work)
// Essential for testing skin-tones and organic "warmth"
pub const SKIN_DEEP = Color.initRgba(115, 62, 57, 255);
pub const SKIN_WARM = Color.initRgba(191, 121, 88, 255);
pub const SKIN_PALE = Color.initRgba(230, 190, 181, 255);
pub const BONE_IVORY = Color.initRgba(235, 229, 206, 255);

// 3. THE "POISON & ACID" FAMILY (Vibrant Hazards)
// High-visibility greens and yellows for gameplay hazards
pub const ACID_CORE = Color.initRgba(204, 255, 0, 255);
pub const ACID_STING = Color.initRgba(127, 255, 0, 255);
pub const ACID_MUD = Color.initRgba(45, 89, 0, 255);

// 4. THE "DREAM & VAPOR" FAMILY (Pastel/Surreal)
// Use for "Magical" effects or dream sequences
pub const VAPOR_BLUE = Color.initRgba(113, 233, 232, 255);
pub const VAPOR_PINK = Color.initRgba(255, 113, 206, 255);
pub const VAPOR_PURPLE = Color.initRgba(185, 103, 255, 255);
pub const VAPOR_SUN = Color.initRgba(255, 251, 150, 255);

// 5. THE "WOOD & BARK" FAMILY (Nature/Structure)
// Specifically tuned for pixel-art dithering on trees/houses
pub const BARK_SHADOW = Color.initRgba(44, 33, 55, 255);
pub const BARK_BASE = Color.initRgba(102, 57, 49, 255);
pub const BARK_LIGHT = Color.initRgba(143, 86, 59, 255);
pub const WOOD_GRAIN = Color.initRgba(189, 137, 74, 255);

// 6. THE "SYSTEM / DEBUG" FAMILY (Engine Utility)
// For things that should NEVER be in a final sprite (transparency, logic)
pub const DEBUG_MAGENTA = Color.initRgba(255, 0, 255, 255);
pub const HITBOX_RED = Color.initRgba(255, 0, 0, 128);
pub const TRIGGER_BLUE = Color.initRgba(0, 0, 255, 128);

// ============================================================================
// OCEAN & WATER
// ============================================================================
pub const SHALLOW_WATER = Color.initRgba(64, 164, 223, 255);
pub const DEEP_WATER = Color.initRgba(28, 107, 160, 255);
pub const FOAM_WHITE = Color.initRgba(230, 245, 255, 255);
pub const SEAFOAM = Color.initRgba(143, 188, 143, 255);
pub const TROPICAL_WATER = Color.initRgba(0, 206, 209, 255);
pub const LAGOON = Color.initRgba(72, 209, 204, 255);
pub const ABYSS_BLUE = Color.initRgba(0, 27, 46, 255);
pub const CORAL_REEF = Color.initRgba(255, 127, 80, 255);
pub const KELP_GREEN = Color.initRgba(47, 79, 47, 255);
pub const BIOLUMINESCENT = Color.initRgba(0, 255, 127, 255);
pub const MURKY_WATER = Color.initRgba(62, 87, 79, 255);
pub const ARCTIC_WATER = Color.initRgba(173, 216, 230, 255);

// ============================================================================
// FIRE & LAVA
// ============================================================================
pub const EMBER_CORE = Color.initRgba(255, 100, 0, 255);
pub const LAVA_ORANGE = Color.initRgba(255, 69, 0, 255);
pub const FLAME_YELLOW = Color.initRgba(255, 200, 0, 255);
pub const ASH_GRAY = Color.initRgba(80, 80, 80, 255);
pub const MOLTEN_GOLD = Color.initRgba(255, 180, 0, 255);
pub const INFERNO_RED = Color.initRgba(255, 47, 0, 255);
pub const CINDER_BLACK = Color.initRgba(35, 25, 20, 255);
pub const SMOKE_GRAY = Color.initRgba(96, 96, 96, 255);
pub const CHARCOAL = Color.initRgba(54, 54, 54, 255);
pub const SOOT = Color.initRgba(28, 28, 28, 255);
pub const BURNING_ORANGE = Color.initRgba(255, 140, 0, 255);
pub const HELLFIRE = Color.initRgba(180, 0, 0, 255);
pub const MAGMA_CORE = Color.initRgba(255, 55, 0, 255);
pub const COOLING_LAVA = Color.initRgba(120, 40, 30, 255);
pub const VOLCANIC_ASH = Color.initRgba(65, 65, 65, 255);

// ============================================================================
// ICE & CRYSTAL
// ============================================================================
pub const ICE_CORE = Color.initRgba(200, 233, 255, 255);
pub const ICE_SHADOW = Color.initRgba(100, 149, 237, 255);
pub const CRYSTAL_PINK = Color.initRgba(255, 182, 193, 255);
pub const PERMAFROST = Color.initRgba(176, 224, 230, 255);
pub const GLACIER_BLUE = Color.initRgba(119, 181, 254, 255);
pub const FROZEN_LAKE = Color.initRgba(144, 195, 212, 255);
pub const SNOW_WHITE = Color.initRgba(255, 250, 250, 255);
pub const FROST_BITE = Color.initRgba(185, 215, 240, 255);
pub const AMETHYST = Color.initRgba(153, 102, 204, 255);
pub const EMERALD = Color.initRgba(80, 200, 120, 255);
pub const RUBY = Color.initRgba(224, 17, 95, 255);
pub const SAPPHIRE = Color.initRgba(15, 82, 186, 255);
pub const TOPAZ = Color.initRgba(255, 200, 124, 255);
pub const DIAMOND = Color.initRgba(185, 242, 255, 255);
pub const OBSIDIAN = Color.initRgba(20, 20, 25, 255);
pub const OPAL = Color.initRgba(168, 195, 188, 255);
pub const QUARTZ = Color.initRgba(217, 217, 217, 255);
pub const CITRINE = Color.initRgba(228, 208, 10, 255);
pub const JADE = Color.initRgba(0, 168, 107, 255);
pub const TURQUOISE = Color.initRgba(64, 224, 208, 255);
pub const AQUAMARINE = Color.initRgba(127, 255, 212, 255);
pub const PERIDOT = Color.initRgba(180, 210, 0, 255);
pub const MOONSTONE = Color.initRgba(199, 206, 214, 255);
pub const ALEXANDRITE = Color.initRgba(106, 90, 205, 255);
pub const GARNET = Color.initRgba(130, 0, 67, 255);

// ============================================================================
// BLOOD & GORE
// ============================================================================
pub const BLOOD_FRESH = Color.initRgba(138, 3, 3, 255);
pub const BLOOD_DARK = Color.initRgba(80, 0, 0, 255);
pub const BLOOD_DRIED = Color.initRgba(100, 20, 20, 255);
pub const BLOOD_BRIGHT = Color.initRgba(185, 15, 15, 255);
pub const ARTERIAL_RED = Color.initRgba(170, 0, 17, 255);
pub const VENOUS_PURPLE = Color.initRgba(75, 0, 30, 255);
pub const BRUISE_PURPLE = Color.initRgba(74, 48, 78, 255);
pub const BRUISE_YELLOW = Color.initRgba(151, 143, 80, 255);
pub const BRUISE_GREEN = Color.initRgba(82, 94, 60, 255);
pub const WOUND_PINK = Color.initRgba(255, 145, 164, 255);
pub const SCAB_BROWN = Color.initRgba(86, 33, 33, 255);
pub const INFECTED_GREEN = Color.initRgba(128, 155, 80, 255);
pub const PUS_YELLOW = Color.initRgba(235, 219, 140, 255);

// ============================================================================
// MAGIC & FANTASY
// ============================================================================
pub const ARCANE_PURPLE = Color.initRgba(138, 43, 226, 255);
pub const MANA_BLUE = Color.initRgba(0, 191, 255, 255);
pub const HOLY_GOLD = Color.initRgba(255, 223, 0, 255);
pub const SHADOW_VOID = Color.initRgba(25, 10, 40, 255);
pub const NECRO_GREEN = Color.initRgba(0, 100, 0, 255);
pub const FEY_PINK = Color.initRgba(255, 105, 180, 255);
pub const ELDRITCH_TEAL = Color.initRgba(0, 139, 139, 255);
pub const CELESTIAL_WHITE = Color.initRgba(255, 255, 240, 255);
pub const DEMONIC_RED = Color.initRgba(139, 0, 0, 255);
pub const SPECTRAL_BLUE = Color.initRgba(135, 206, 250, 255);
pub const DRUID_GREEN = Color.initRgba(85, 107, 47, 255);
pub const WITCH_PURPLE = Color.initRgba(75, 0, 130, 255);
pub const PORTAL_CYAN = Color.initRgba(0, 255, 255, 255);
pub const ENCHANT_LAVENDER = Color.initRgba(230, 190, 255, 255);
pub const CURSE_BLACK = Color.initRgba(20, 5, 30, 255);
pub const BLESSING_AMBER = Color.initRgba(255, 191, 0, 255);
pub const ETHER_SILVER = Color.initRgba(211, 211, 211, 255);
pub const ASTRAL_INDIGO = Color.initRgba(75, 0, 130, 255);
pub const PHOENIX_ORANGE = Color.initRgba(255, 117, 24, 255);
pub const DRAGON_SCALES = Color.initRgba(64, 130, 109, 255);
pub const UNICORN_WHITE = Color.initRgba(253, 251, 255, 255);
pub const FAIRY_DUST = Color.initRgba(255, 215, 255, 255);
pub const GOBLIN_GREEN = Color.initRgba(53, 94, 59, 255);
pub const ORC_BROWN = Color.initRgba(85, 60, 42, 255);
pub const TROLL_GRAY = Color.initRgba(90, 90, 80, 255);
pub const VAMPIRE_RED = Color.initRgba(120, 0, 20, 255);
pub const WEREWOLF_BROWN = Color.initRgba(101, 67, 33, 255);
pub const ZOMBIE_GREEN = Color.initRgba(107, 142, 35, 255);
pub const GHOST_WHITE = Color.initRgba(248, 248, 255, 255);
pub const WRAITH_BLUE = Color.initRgba(100, 149, 237, 255);
pub const LICH_PURPLE = Color.initRgba(72, 61, 139, 255);
pub const GOLEM_STONE = Color.initRgba(136, 140, 141, 255);
pub const SLIME_GREEN = Color.initRgba(132, 222, 2, 255);
pub const SLIME_BLUE = Color.initRgba(80, 200, 255, 255);
pub const SLIME_PINK = Color.initRgba(255, 110, 199, 255);

// ============================================================================
// METAL & MINERAL
// ============================================================================
pub const COPPER = Color.initRgba(184, 115, 51, 255);
pub const COPPER_PATINA = Color.initRgba(77, 122, 108, 255);
pub const RUST = Color.initRgba(183, 65, 14, 255);
pub const RUST_DARK = Color.initRgba(113, 45, 14, 255);
pub const IRON = Color.initRgba(82, 82, 82, 255);
pub const IRON_DARK = Color.initRgba(52, 52, 54, 255);
pub const TITANIUM = Color.initRgba(135, 134, 129, 255);
pub const PLATINUM = Color.initRgba(229, 228, 226, 255);
pub const CHROME = Color.initRgba(219, 226, 233, 255);
pub const BRASS = Color.initRgba(181, 166, 66, 255);
pub const PEWTER = Color.initRgba(150, 155, 157, 255);
pub const NICKEL = Color.initRgba(114, 116, 114, 255);
pub const LEAD = Color.initRgba(86, 86, 86, 255);
pub const TIN = Color.initRgba(145, 145, 145, 255);
pub const COBALT = Color.initRgba(0, 71, 171, 255);
pub const MERCURY = Color.initRgba(194, 194, 194, 255);
pub const MITHRIL = Color.initRgba(196, 207, 221, 255);
pub const ADAMANTINE = Color.initRgba(90, 110, 90, 255);
pub const ORICHALCUM = Color.initRgba(205, 127, 50, 255);
pub const ELECTRUM = Color.initRgba(207, 181, 59, 255);
pub const COAL = Color.initRgba(35, 35, 35, 255);
pub const GRANITE = Color.initRgba(130, 130, 130, 255);
pub const MARBLE_WHITE = Color.initRgba(245, 245, 245, 255);
pub const MARBLE_BLACK = Color.initRgba(30, 30, 30, 255);
pub const SANDSTONE = Color.initRgba(210, 180, 140, 255);
pub const LIMESTONE = Color.initRgba(218, 214, 198, 255);
pub const BASALT = Color.initRgba(48, 48, 48, 255);
pub const SHALE = Color.initRgba(90, 88, 83, 255);
pub const SLATE_ROCK = Color.initRgba(47, 79, 79, 255);
pub const PUMICE = Color.initRgba(155, 155, 145, 255);
pub const FLINT = Color.initRgba(67, 70, 75, 255);
pub const CLAY_RED = Color.initRgba(170, 74, 68, 255);
pub const CLAY_GRAY = Color.initRgba(130, 130, 120, 255);

// ============================================================================
// WOOD TYPES
// ============================================================================
pub const OAK_LIGHT = Color.initRgba(190, 158, 108, 255);
pub const OAK_DARK = Color.initRgba(120, 81, 45, 255);
pub const PINE = Color.initRgba(195, 176, 145, 255);
pub const BIRCH = Color.initRgba(245, 235, 220, 255);
pub const MAHOGANY = Color.initRgba(103, 49, 71, 255);
pub const CHERRY_WOOD = Color.initRgba(150, 63, 50, 255);
pub const WALNUT = Color.initRgba(93, 61, 38, 255);
pub const EBONY = Color.initRgba(33, 28, 27, 255);
pub const TEAK = Color.initRgba(176, 131, 72, 255);
pub const MAPLE = Color.initRgba(230, 195, 150, 255);
pub const ASH_WOOD = Color.initRgba(224, 208, 183, 255);
pub const CEDAR = Color.initRgba(172, 98, 60, 255);
pub const REDWOOD = Color.initRgba(164, 90, 82, 255);
pub const BAMBOO = Color.initRgba(200, 180, 130, 255);
pub const DRIFTWOOD = Color.initRgba(156, 147, 129, 255);
pub const ROTTEN_WOOD = Color.initRgba(74, 63, 54, 255);
pub const MOSSY_WOOD = Color.initRgba(95, 100, 75, 255);

// ============================================================================
// FABRIC & TEXTILE
// ============================================================================
pub const LINEN = Color.initRgba(250, 240, 230, 255);
pub const BURLAP = Color.initRgba(135, 114, 85, 255);
pub const SILK_WHITE = Color.initRgba(255, 253, 250, 255);
pub const SILK_RED = Color.initRgba(170, 42, 42, 255);
pub const SILK_BLUE = Color.initRgba(65, 105, 225, 255);
pub const SILK_GOLD = Color.initRgba(212, 175, 55, 255);
pub const VELVET_PURPLE = Color.initRgba(75, 0, 90, 255);
pub const VELVET_RED = Color.initRgba(120, 20, 30, 255);
pub const VELVET_BLUE = Color.initRgba(25, 25, 112, 255);
pub const VELVET_GREEN = Color.initRgba(0, 80, 60, 255);
pub const DENIM = Color.initRgba(21, 96, 189, 255);
pub const DENIM_FADED = Color.initRgba(100, 149, 237, 255);
pub const CANVAS = Color.initRgba(227, 218, 201, 255);
pub const WOOL_WHITE = Color.initRgba(245, 243, 240, 255);
pub const WOOL_GRAY = Color.initRgba(160, 160, 160, 255);
pub const WOOL_BROWN = Color.initRgba(130, 100, 70, 255);
pub const LEATHER_TAN = Color.initRgba(180, 134, 90, 255);
pub const LEATHER_BROWN = Color.initRgba(102, 68, 40, 255);
pub const LEATHER_BLACK = Color.initRgba(40, 35, 30, 255);
pub const SUEDE = Color.initRgba(170, 140, 110, 255);
pub const COTTON = Color.initRgba(251, 251, 251, 255);
pub const HEMP = Color.initRgba(165, 150, 115, 255);
pub const SATIN = Color.initRgba(200, 180, 160, 255);
pub const CORDUROY = Color.initRgba(140, 100, 75, 255);
pub const TWEED = Color.initRgba(145, 135, 115, 255);

// ============================================================================
// FOOD & ORGANIC
// ============================================================================
pub const APPLE_RED = Color.initRgba(200, 35, 51, 255);
pub const APPLE_GREEN = Color.initRgba(168, 212, 93, 255);
pub const BANANA_YELLOW = Color.initRgba(252, 224, 70, 255);
pub const BANANA_BROWN = Color.initRgba(107, 68, 35, 255);
pub const ORANGE_FRUIT = Color.initRgba(255, 165, 0, 255);
pub const LEMON = Color.initRgba(255, 239, 0, 255);
pub const LIME_FRUIT = Color.initRgba(191, 255, 0, 255);
pub const GRAPE_PURPLE = Color.initRgba(107, 63, 160, 255);
pub const GRAPE_GREEN = Color.initRgba(178, 236, 93, 255);
pub const STRAWBERRY = Color.initRgba(252, 90, 141, 255);
pub const BLUEBERRY = Color.initRgba(79, 134, 247, 255);
pub const RASPBERRY = Color.initRgba(227, 11, 93, 255);
pub const BLACKBERRY = Color.initRgba(50, 20, 50, 255);
pub const WATERMELON_RIND = Color.initRgba(129, 189, 112, 255);
pub const WATERMELON_FLESH = Color.initRgba(252, 108, 133, 255);
pub const PEACH = Color.initRgba(255, 218, 185, 255);
pub const PLUM = Color.initRgba(142, 69, 133, 255);
pub const CHERRY = Color.initRgba(222, 49, 99, 255);
pub const AVOCADO_SKIN = Color.initRgba(51, 70, 47, 255);
pub const AVOCADO_FLESH = Color.initRgba(175, 186, 123, 255);
pub const TOMATO = Color.initRgba(255, 99, 71, 255);
pub const CARROT = Color.initRgba(255, 140, 26, 255);
pub const LETTUCE = Color.initRgba(172, 225, 175, 255);
pub const CUCUMBER = Color.initRgba(119, 178, 85, 255);
pub const EGGPLANT = Color.initRgba(97, 64, 81, 255);
pub const PUMPKIN = Color.initRgba(255, 117, 24, 255);
pub const CORN = Color.initRgba(251, 236, 93, 255);
pub const WHEAT = Color.initRgba(245, 222, 179, 255);
pub const BREAD_CRUST = Color.initRgba(150, 111, 51, 255);
pub const BREAD_CRUMB = Color.initRgba(235, 215, 180, 255);
pub const CHOCOLATE_DARK = Color.initRgba(62, 28, 13, 255);
pub const CHOCOLATE_MILK = Color.initRgba(123, 63, 0, 255);
pub const CHOCOLATE_WHITE = Color.initRgba(251, 243, 226, 255);
pub const CARAMEL = Color.initRgba(255, 185, 83, 255);
pub const HONEY = Color.initRgba(235, 177, 52, 255);
pub const MAPLE_SYRUP = Color.initRgba(187, 97, 19, 255);
pub const COFFEE = Color.initRgba(111, 78, 55, 255);
pub const ESPRESSO = Color.initRgba(65, 43, 31, 255);
pub const CREAM = Color.initRgba(255, 253, 208, 255);
pub const BUTTER = Color.initRgba(255, 241, 150, 255);
pub const CHEESE_YELLOW = Color.initRgba(255, 196, 0, 255);
pub const CHEESE_ORANGE = Color.initRgba(255, 148, 54, 255);
pub const CHEESE_WHITE = Color.initRgba(255, 245, 220, 255);
pub const EGG_WHITE = Color.initRgba(255, 255, 245, 255);
pub const EGG_YOLK = Color.initRgba(255, 197, 61, 255);
pub const BACON = Color.initRgba(160, 75, 65, 255);
pub const STEAK_RAW = Color.initRgba(180, 50, 50, 255);
pub const STEAK_COOKED = Color.initRgba(120, 70, 50, 255);
pub const FISH_RAW = Color.initRgba(255, 180, 173, 255);
pub const FISH_COOKED = Color.initRgba(230, 200, 170, 255);
pub const SHRIMP = Color.initRgba(255, 160, 137, 255);
pub const LOBSTER = Color.initRgba(200, 50, 30, 255);

// ============================================================================
// NATURE - PLANTS & FOLIAGE
// ============================================================================
pub const GRASS_SPRING = Color.initRgba(124, 252, 0, 255);
pub const GRASS_SUMMER = Color.initRgba(60, 179, 60, 255);
pub const GRASS_AUTUMN = Color.initRgba(139, 137, 89, 255);
pub const GRASS_DEAD = Color.initRgba(170, 155, 110, 255);
pub const LEAF_SPRING = Color.initRgba(144, 238, 144, 255);
pub const LEAF_SUMMER = Color.initRgba(34, 139, 34, 255);
pub const LEAF_AUTUMN_YELLOW = Color.initRgba(255, 215, 0, 255);
pub const LEAF_AUTUMN_ORANGE = Color.initRgba(255, 140, 0, 255);
pub const LEAF_AUTUMN_RED = Color.initRgba(205, 92, 92, 255);
pub const LEAF_AUTUMN_BROWN = Color.initRgba(139, 90, 43, 255);
pub const MOSS = Color.initRgba(138, 154, 91, 255);
pub const MOSS_DARK = Color.initRgba(85, 107, 47, 255);
pub const LICHEN = Color.initRgba(176, 196, 172, 255);
pub const IVY = Color.initRgba(52, 78, 65, 255);
pub const FERN = Color.initRgba(79, 121, 66, 255);
pub const CLOVER = Color.initRgba(63, 122, 77, 255);
pub const SEAWEED = Color.initRgba(46, 80, 60, 255);
pub const ALGAE = Color.initRgba(77, 133, 83, 255);
pub const CACTUS = Color.initRgba(88, 130, 77, 255);
pub const SUCCULENT = Color.initRgba(127, 176, 144, 255);
pub const BAMBOO_LEAF = Color.initRgba(113, 148, 78, 255);
pub const PALM_FROND = Color.initRgba(79, 121, 66, 255);
pub const PINE_NEEDLE = Color.initRgba(47, 79, 47, 255);
pub const WILLOW = Color.initRgba(154, 185, 115, 255);

// ============================================================================
// NATURE - FLOWERS
// ============================================================================
pub const ROSE_RED = Color.initRgba(194, 30, 86, 255);
pub const ROSE_PINK = Color.initRgba(255, 153, 172, 255);
pub const ROSE_WHITE = Color.initRgba(255, 245, 238, 255);
pub const ROSE_YELLOW = Color.initRgba(255, 240, 88, 255);
pub const TULIP_RED = Color.initRgba(227, 66, 52, 255);
pub const TULIP_PINK = Color.initRgba(255, 183, 197, 255);
pub const TULIP_PURPLE = Color.initRgba(150, 111, 214, 255);
pub const TULIP_YELLOW = Color.initRgba(255, 234, 0, 255);
pub const SUNFLOWER = Color.initRgba(255, 204, 0, 255);
pub const DAISY_WHITE = Color.initRgba(255, 255, 240, 255);
pub const DAISY_CENTER = Color.initRgba(255, 204, 0, 255);
pub const LAVENDER_FLOWER = Color.initRgba(181, 126, 220, 255);
pub const VIOLET = Color.initRgba(143, 0, 255, 255);
pub const ORCHID = Color.initRgba(218, 112, 214, 255);
pub const LILY_WHITE = Color.initRgba(255, 250, 250, 255);
pub const LILY_ORANGE = Color.initRgba(255, 140, 0, 255);
pub const IRIS_PURPLE = Color.initRgba(93, 63, 211, 255);
pub const IRIS_YELLOW = Color.initRgba(255, 255, 102, 255);
pub const CARNATION_RED = Color.initRgba(255, 69, 106, 255);
pub const CARNATION_PINK = Color.initRgba(255, 182, 193, 255);
pub const HIBISCUS = Color.initRgba(181, 23, 67, 255);
pub const MARIGOLD = Color.initRgba(255, 165, 0, 255);
pub const CHRYSANTHEMUM = Color.initRgba(255, 201, 14, 255);
pub const POPPY = Color.initRgba(228, 55, 36, 255);
pub const BLUEBELL = Color.initRgba(95, 158, 209, 255);
pub const DANDELION = Color.initRgba(253, 218, 13, 255);
pub const CLOVER_FLOWER = Color.initRgba(255, 192, 203, 255);
pub const WISTERIA = Color.initRgba(201, 160, 220, 255);
pub const MAGNOLIA = Color.initRgba(248, 232, 220, 255);
pub const PEONY = Color.initRgba(237, 118, 162, 255);
pub const CAMELLIA = Color.initRgba(233, 150, 170, 255);
pub const JASMINE = Color.initRgba(248, 222, 126, 255);
pub const LOTUS = Color.initRgba(255, 183, 205, 255);

// ============================================================================
// NATURE - SKY & ATMOSPHERE
// ============================================================================
pub const DAWN_PINK = Color.initRgba(255, 178, 172, 255);
pub const DAWN_ORANGE = Color.initRgba(255, 165, 115, 255);
pub const DAWN_PURPLE = Color.initRgba(147, 112, 219, 255);
pub const SUNRISE_YELLOW = Color.initRgba(255, 223, 120, 255);
pub const MORNING_BLUE = Color.initRgba(135, 206, 250, 255);
pub const NOON_BLUE = Color.initRgba(100, 149, 237, 255);
pub const AFTERNOON_BLUE = Color.initRgba(135, 206, 235, 255);
pub const SUNSET_ORANGE = Color.initRgba(255, 100, 60, 255);
pub const SUNSET_RED = Color.initRgba(255, 69, 0, 255);
pub const SUNSET_PINK = Color.initRgba(255, 145, 164, 255);
pub const SUNSET_PURPLE = Color.initRgba(180, 105, 175, 255);
pub const DUSK_BLUE = Color.initRgba(65, 74, 106, 255);
pub const DUSK_PURPLE = Color.initRgba(90, 77, 105, 255);
pub const TWILIGHT = Color.initRgba(78, 81, 128, 255);
pub const NIGHT_SKY = Color.initRgba(25, 25, 50, 255);
pub const MIDNIGHT = Color.initRgba(18, 18, 35, 255);
pub const STARLIGHT = Color.initRgba(255, 255, 210, 255);
pub const MOONLIGHT = Color.initRgba(235, 245, 255, 255);
pub const AURORA_GREEN = Color.initRgba(115, 255, 155, 255);
pub const AURORA_BLUE = Color.initRgba(90, 200, 250, 255);
pub const AURORA_PURPLE = Color.initRgba(190, 130, 255, 255);
pub const AURORA_PINK = Color.initRgba(255, 130, 200, 255);
pub const CLOUD_WHITE = Color.initRgba(255, 255, 255, 255);
pub const CLOUD_GRAY = Color.initRgba(200, 200, 200, 255);
pub const STORM_CLOUD = Color.initRgba(95, 95, 95, 255);
pub const THUNDER_GRAY = Color.initRgba(65, 65, 75, 255);
pub const RAIN_BLUE = Color.initRgba(174, 194, 224, 255);
pub const FOG = Color.initRgba(220, 220, 220, 255);
pub const MIST = Color.initRgba(235, 235, 235, 255);
pub const SMOG = Color.initRgba(170, 165, 150, 255);
pub const HAZE = Color.initRgba(210, 200, 180, 255);
pub const RAINBOW_RED = Color.initRgba(255, 0, 0, 255);
pub const RAINBOW_ORANGE = Color.initRgba(255, 127, 0, 255);
pub const RAINBOW_YELLOW = Color.initRgba(255, 255, 0, 255);
pub const RAINBOW_GREEN = Color.initRgba(0, 255, 0, 255);
pub const RAINBOW_BLUE = Color.initRgba(0, 0, 255, 255);
pub const RAINBOW_INDIGO = Color.initRgba(75, 0, 130, 255);
pub const RAINBOW_VIOLET = Color.initRgba(143, 0, 255, 255);

// ============================================================================
// NATURE - EARTH & TERRAIN
// ============================================================================
pub const DIRT_LIGHT = Color.initRgba(155, 118, 83, 255);
pub const DIRT_DARK = Color.initRgba(92, 64, 51, 255);
pub const DIRT_RED = Color.initRgba(135, 68, 44, 255);
pub const SOIL_RICH = Color.initRgba(69, 48, 34, 255);
pub const CLAY_TAN = Color.initRgba(200, 160, 120, 255);
pub const CLAY_TERRACOTTA = Color.initRgba(204, 119, 93, 255);
pub const PEAT = Color.initRgba(45, 35, 25, 255);
pub const LOAM = Color.initRgba(110, 85, 60, 255);
pub const SILT = Color.initRgba(160, 140, 120, 255);
pub const GRAVEL = Color.initRgba(140, 140, 140, 255);
pub const PEBBLE = Color.initRgba(170, 165, 160, 255);
pub const BOULDER_GRAY = Color.initRgba(100, 100, 100, 255);
pub const BOULDER_BROWN = Color.initRgba(95, 85, 75, 255);
pub const CAVE_WALL = Color.initRgba(55, 50, 50, 255);
pub const STALACTITE = Color.initRgba(180, 175, 170, 255);
pub const STALAGMITE = Color.initRgba(165, 155, 145, 255);
pub const CRYSTAL_CAVE = Color.initRgba(160, 180, 200, 255);
pub const VOLCANIC_ROCK = Color.initRgba(45, 40, 40, 255);
pub const PUMICE_STONE = Color.initRgba(200, 195, 185, 255);
pub const CHALK = Color.initRgba(245, 243, 240, 255);
pub const SALT_FLAT = Color.initRgba(250, 250, 250, 255);
pub const RED_ROCK = Color.initRgba(165, 77, 42, 255);
pub const CANYON_ORANGE = Color.initRgba(204, 119, 68, 255);
pub const MESA = Color.initRgba(190, 130, 90, 255);

// ============================================================================
// ARCHITECTURE & BUILDING
// ============================================================================
pub const BRICK_RED = Color.initRgba(156, 66, 43, 255);
pub const BRICK_ORANGE = Color.initRgba(178, 100, 60, 255);
pub const BRICK_BROWN = Color.initRgba(130, 85, 60, 255);
pub const BRICK_GRAY = Color.initRgba(140, 130, 125, 255);
pub const MORTAR = Color.initRgba(180, 175, 170, 255);
pub const CONCRETE = Color.initRgba(145, 145, 145, 255);
pub const CONCRETE_DARK = Color.initRgba(100, 100, 100, 255);
pub const CONCRETE_LIGHT = Color.initRgba(190, 190, 190, 255);
pub const CEMENT = Color.initRgba(160, 160, 160, 255);
pub const STUCCO = Color.initRgba(230, 220, 200, 255);
pub const PLASTER = Color.initRgba(240, 235, 225, 255);
pub const DRYWALL = Color.initRgba(245, 245, 240, 255);
pub const TILE_WHITE = Color.initRgba(245, 245, 245, 255);
pub const TILE_CREAM = Color.initRgba(245, 235, 220, 255);
pub const TILE_TERRACOTTA = Color.initRgba(195, 110, 85, 255);
pub const TILE_BLUE = Color.initRgba(65, 105, 170, 255);
pub const TILE_GREEN = Color.initRgba(90, 135, 100, 255);
pub const SHINGLE_GRAY = Color.initRgba(105, 105, 105, 255);
pub const SHINGLE_RED = Color.initRgba(140, 75, 60, 255);
pub const SHINGLE_BROWN = Color.initRgba(115, 85, 65, 255);
pub const THATCH = Color.initRgba(190, 170, 130, 255);
pub const SLATE_ROOF = Color.initRgba(70, 85, 95, 255);
pub const COPPER_ROOF = Color.initRgba(75, 115, 100, 255);
pub const GLASS = Color.initRgba(200, 225, 235, 200);
pub const GLASS_TINTED = Color.initRgba(150, 175, 185, 220);
pub const GLASS_FROSTED = Color.initRgba(220, 230, 235, 235);
pub const WINDOW_FRAME = Color.initRgba(60, 60, 60, 255);
pub const DOOR_BROWN = Color.initRgba(101, 67, 33, 255);
pub const DOOR_RED = Color.initRgba(139, 35, 35, 255);
pub const DOOR_GREEN = Color.initRgba(34, 85, 51, 255);
pub const FENCE_WHITE = Color.initRgba(245, 245, 245, 255);
pub const FENCE_BROWN = Color.initRgba(115, 80, 55, 255);

// ============================================================================
// TECHNOLOGY & UI
// ============================================================================
pub const SCREEN_BLACK = Color.initRgba(15, 15, 15, 255);
pub const SCREEN_BLUE = Color.initRgba(0, 40, 80, 255);
pub const SCREEN_GREEN = Color.initRgba(0, 40, 0, 255);
pub const TERMINAL_GREEN = Color.initRgba(0, 255, 0, 255);
pub const TERMINAL_AMBER = Color.initRgba(255, 176, 0, 255);
pub const TERMINAL_WHITE = Color.initRgba(255, 255, 255, 255);
pub const LED_RED = Color.initRgba(255, 30, 30, 255);
pub const LED_GREEN = Color.initRgba(30, 255, 30, 255);
pub const LED_BLUE = Color.initRgba(30, 100, 255, 255);
pub const LED_YELLOW = Color.initRgba(255, 230, 30, 255);
pub const LED_ORANGE = Color.initRgba(255, 140, 30, 255);
pub const LED_WHITE = Color.initRgba(255, 255, 255, 255);
pub const LED_OFF = Color.initRgba(50, 50, 50, 255);
pub const CIRCUIT_GREEN = Color.initRgba(0, 80, 0, 255);
pub const CIRCUIT_TRACE = Color.initRgba(180, 160, 90, 255);
pub const SOLDER = Color.initRgba(190, 190, 190, 255);
pub const WIRE_RED = Color.initRgba(200, 30, 30, 255);
pub const WIRE_BLACK = Color.initRgba(30, 30, 30, 255);
pub const WIRE_BLUE = Color.initRgba(30, 100, 200, 255);
pub const WIRE_YELLOW = Color.initRgba(230, 200, 30, 255);
pub const WIRE_GREEN = Color.initRgba(30, 150, 30, 255);
pub const WIRE_WHITE = Color.initRgba(230, 230, 230, 255);
pub const WIRE_ORANGE = Color.initRgba(255, 140, 30, 255);
pub const WIRE_BROWN = Color.initRgba(130, 90, 50, 255);
pub const PLASTIC_WHITE = Color.initRgba(240, 240, 235, 255);
pub const PLASTIC_BLACK = Color.initRgba(35, 35, 35, 255);
pub const PLASTIC_GRAY = Color.initRgba(140, 140, 140, 255);
pub const PLASTIC_BLUE = Color.initRgba(50, 100, 180, 255);
pub const PLASTIC_RED = Color.initRgba(180, 50, 50, 255);
pub const RUBBER_BLACK = Color.initRgba(25, 25, 25, 255);
pub const RUBBER_GRAY = Color.initRgba(80, 80, 80, 255);
pub const KEYBOARD_KEY = Color.initRgba(55, 55, 55, 255);
pub const KEYBOARD_LEGEND = Color.initRgba(200, 200, 200, 255);

// ============================================================================
// VINTAGE PALETTES - CGA
// ============================================================================
pub const CGA_BLACK = Color.initRgba(0, 0, 0, 255);
pub const CGA_BLUE = Color.initRgba(0, 0, 170, 255);
pub const CGA_GREEN = Color.initRgba(0, 170, 0, 255);
pub const CGA_CYAN = Color.initRgba(0, 170, 170, 255);
pub const CGA_RED = Color.initRgba(170, 0, 0, 255);
pub const CGA_MAGENTA = Color.initRgba(170, 0, 170, 255);
pub const CGA_BROWN = Color.initRgba(170, 85, 0, 255);
pub const CGA_LIGHT_GRAY = Color.initRgba(170, 170, 170, 255);
pub const CGA_DARK_GRAY = Color.initRgba(85, 85, 85, 255);
pub const CGA_LIGHT_BLUE = Color.initRgba(85, 85, 255, 255);
pub const CGA_LIGHT_GREEN = Color.initRgba(85, 255, 85, 255);
pub const CGA_LIGHT_CYAN = Color.initRgba(85, 255, 255, 255);
pub const CGA_LIGHT_RED = Color.initRgba(255, 85, 85, 255);
pub const CGA_LIGHT_MAGENTA = Color.initRgba(255, 85, 255, 255);
pub const CGA_YELLOW = Color.initRgba(255, 255, 85, 255);
pub const CGA_WHITE = Color.initRgba(255, 255, 255, 255);

// ============================================================================
// VINTAGE PALETTES - EGA
// ============================================================================
pub const EGA_BLACK = Color.initRgba(0, 0, 0, 255);
pub const EGA_BLUE = Color.initRgba(0, 0, 170, 255);
pub const EGA_GREEN = Color.initRgba(0, 170, 0, 255);
pub const EGA_CYAN = Color.initRgba(0, 170, 170, 255);
pub const EGA_RED = Color.initRgba(170, 0, 0, 255);
pub const EGA_MAGENTA = Color.initRgba(170, 0, 170, 255);
pub const EGA_BROWN = Color.initRgba(170, 85, 0, 255);
pub const EGA_LIGHT_GRAY = Color.initRgba(170, 170, 170, 255);
pub const EGA_DARK_GRAY = Color.initRgba(85, 85, 85, 255);
pub const EGA_BRIGHT_BLUE = Color.initRgba(85, 85, 255, 255);
pub const EGA_BRIGHT_GREEN = Color.initRgba(85, 255, 85, 255);
pub const EGA_BRIGHT_CYAN = Color.initRgba(85, 255, 255, 255);
pub const EGA_BRIGHT_RED = Color.initRgba(255, 85, 85, 255);
pub const EGA_BRIGHT_MAGENTA = Color.initRgba(255, 85, 255, 255);
pub const EGA_YELLOW = Color.initRgba(255, 255, 85, 255);
pub const EGA_WHITE = Color.initRgba(255, 255, 255, 255);

// ============================================================================
// VINTAGE PALETTES - COMMODORE 64
// ============================================================================
pub const C64_BLACK = Color.initRgba(0, 0, 0, 255);
pub const C64_WHITE = Color.initRgba(255, 255, 255, 255);
pub const C64_RED = Color.initRgba(136, 0, 0, 255);
pub const C64_CYAN = Color.initRgba(170, 255, 238, 255);
pub const C64_PURPLE = Color.initRgba(204, 68, 204, 255);
pub const C64_GREEN = Color.initRgba(0, 204, 85, 255);
pub const C64_BLUE = Color.initRgba(0, 0, 170, 255);
pub const C64_YELLOW = Color.initRgba(238, 238, 119, 255);
pub const C64_ORANGE = Color.initRgba(221, 136, 85, 255);
pub const C64_BROWN = Color.initRgba(102, 68, 0, 255);
pub const C64_LIGHT_RED = Color.initRgba(255, 119, 119, 255);
pub const C64_DARK_GRAY = Color.initRgba(51, 51, 51, 255);
pub const C64_GRAY = Color.initRgba(119, 119, 119, 255);
pub const C64_LIGHT_GREEN = Color.initRgba(170, 255, 102, 255);
pub const C64_LIGHT_BLUE = Color.initRgba(0, 136, 255, 255);
pub const C64_LIGHT_GRAY = Color.initRgba(187, 187, 187, 255);

// ============================================================================
// VINTAGE PALETTES - NES
// ============================================================================
pub const NES_BLACK = Color.initRgba(0, 0, 0, 255);
pub const NES_DARK_GRAY = Color.initRgba(88, 88, 88, 255);
pub const NES_LIGHT_GRAY = Color.initRgba(172, 172, 172, 255);
pub const NES_WHITE = Color.initRgba(252, 252, 252, 255);
pub const NES_DARK_RED = Color.initRgba(168, 16, 0, 255);
pub const NES_RED = Color.initRgba(228, 76, 60, 255);
pub const NES_LIGHT_RED = Color.initRgba(252, 156, 156, 255);
pub const NES_DARK_ORANGE = Color.initRgba(168, 68, 0, 255);
pub const NES_ORANGE = Color.initRgba(228, 124, 44, 255);
pub const NES_LIGHT_ORANGE = Color.initRgba(252, 196, 128, 255);
pub const NES_DARK_YELLOW = Color.initRgba(184, 108, 0, 255);
pub const NES_YELLOW = Color.initRgba(244, 176, 64, 255);
pub const NES_LIGHT_YELLOW = Color.initRgba(252, 228, 160, 255);
pub const NES_DARK_GREEN = Color.initRgba(0, 120, 0, 255);
pub const NES_GREEN = Color.initRgba(76, 184, 64, 255);
pub const NES_LIGHT_GREEN = Color.initRgba(168, 240, 168, 255);
pub const NES_DARK_CYAN = Color.initRgba(0, 120, 92, 255);
pub const NES_CYAN = Color.initRgba(64, 200, 168, 255);
pub const NES_LIGHT_CYAN = Color.initRgba(152, 248, 240, 255);
pub const NES_DARK_BLUE = Color.initRgba(0, 68, 168, 255);
pub const NES_BLUE = Color.initRgba(68, 136, 252, 255);
pub const NES_LIGHT_BLUE = Color.initRgba(164, 200, 252, 255);
pub const NES_DARK_PURPLE = Color.initRgba(88, 0, 168, 255);
pub const NES_PURPLE = Color.initRgba(152, 76, 252, 255);
pub const NES_LIGHT_PURPLE = Color.initRgba(216, 168, 252, 255);
pub const NES_DARK_MAGENTA = Color.initRgba(136, 0, 128, 255);
pub const NES_MAGENTA = Color.initRgba(200, 76, 200, 255);
pub const NES_LIGHT_MAGENTA = Color.initRgba(252, 168, 236, 255);

// ============================================================================
// VINTAGE PALETTES - SNES
// ============================================================================
pub const SNES_BLACK = Color.initRgba(0, 0, 0, 255);
pub const SNES_DARK_BLUE = Color.initRgba(0, 0, 128, 255);
pub const SNES_BLUE = Color.initRgba(0, 0, 255, 255);
pub const SNES_DARK_GREEN = Color.initRgba(0, 128, 0, 255);
pub const SNES_TEAL = Color.initRgba(0, 128, 128, 255);
pub const SNES_GREEN = Color.initRgba(0, 255, 0, 255);
pub const SNES_CYAN = Color.initRgba(0, 255, 255, 255);
pub const SNES_DARK_RED = Color.initRgba(128, 0, 0, 255);
pub const SNES_PURPLE = Color.initRgba(128, 0, 128, 255);
pub const SNES_OLIVE = Color.initRgba(128, 128, 0, 255);
pub const SNES_GRAY = Color.initRgba(128, 128, 128, 255);
pub const SNES_RED = Color.initRgba(255, 0, 0, 255);
pub const SNES_MAGENTA = Color.initRgba(255, 0, 255, 255);
pub const SNES_YELLOW = Color.initRgba(255, 255, 0, 255);
pub const SNES_WHITE = Color.initRgba(255, 255, 255, 255);

// ============================================================================
// VINTAGE PALETTES - PICO-8 (full 32 color secret palette)
// ============================================================================
pub const PICO8_BLACK = Color.initRgba(0, 0, 0, 255);
pub const PICO8_DARK_BLUE = Color.initRgba(29, 43, 83, 255);
pub const PICO8_DARK_PURPLE = Color.initRgba(126, 37, 83, 255);
pub const PICO8_DARK_GREEN = Color.initRgba(0, 135, 81, 255);
pub const PICO8_BROWN = Color.initRgba(171, 82, 54, 255);
pub const PICO8_DARK_GRAY = Color.initRgba(95, 87, 79, 255);
pub const PICO8_LIGHT_GRAY = Color.initRgba(194, 195, 199, 255);
pub const PICO8_WHITE = Color.initRgba(255, 241, 232, 255);
pub const PICO8_RED = Color.initRgba(255, 0, 77, 255);
pub const PICO8_ORANGE = Color.initRgba(255, 163, 0, 255);
pub const PICO8_YELLOW = Color.initRgba(255, 236, 39, 255);
pub const PICO8_GREEN = Color.initRgba(0, 228, 54, 255);
pub const PICO8_BLUE = Color.initRgba(41, 173, 255, 255);
pub const PICO8_LAVENDER = Color.initRgba(131, 118, 156, 255);
pub const PICO8_PINK = Color.initRgba(255, 119, 168, 255);
pub const PICO8_PEACH = Color.initRgba(255, 204, 170, 255);
// Secret palette
pub const PICO8_BROWNISH_BLACK = Color.initRgba(41, 24, 20, 255);
pub const PICO8_DARKER_BLUE = Color.initRgba(17, 29, 53, 255);
pub const PICO8_DARKER_PURPLE = Color.initRgba(66, 33, 54, 255);
pub const PICO8_BLUE_GREEN = Color.initRgba(18, 83, 89, 255);
pub const PICO8_DARK_BROWN = Color.initRgba(116, 47, 41, 255);
pub const PICO8_DARKER_GRAY = Color.initRgba(73, 51, 59, 255);
pub const PICO8_MEDIUM_GRAY = Color.initRgba(162, 136, 121, 255);
pub const PICO8_LIGHT_PEACH = Color.initRgba(243, 239, 125, 255);
pub const PICO8_DARK_RED = Color.initRgba(190, 18, 80, 255);
pub const PICO8_GOLD = Color.initRgba(255, 108, 36, 255);
pub const PICO8_LIME = Color.initRgba(168, 231, 46, 255);
pub const PICO8_BRIGHT_GREEN = Color.initRgba(0, 181, 67, 255);
pub const PICO8_TRUE_BLUE = Color.initRgba(6, 90, 181, 255);
pub const PICO8_MAUVE = Color.initRgba(117, 70, 101, 255);
pub const PICO8_SALMON = Color.initRgba(255, 110, 89, 255);
pub const PICO8_TAN = Color.initRgba(255, 157, 129, 255);

// ============================================================================
// VINTAGE PALETTES - APPLE II
// ============================================================================
pub const APPLE2_BLACK = Color.initRgba(0, 0, 0, 255);
pub const APPLE2_MAGENTA = Color.initRgba(227, 30, 96, 255);
pub const APPLE2_DARK_BLUE = Color.initRgba(96, 78, 189, 255);
pub const APPLE2_PURPLE = Color.initRgba(255, 68, 253, 255);
pub const APPLE2_DARK_GREEN = Color.initRgba(0, 163, 96, 255);
pub const APPLE2_GRAY1 = Color.initRgba(156, 156, 156, 255);
pub const APPLE2_MEDIUM_BLUE = Color.initRgba(20, 207, 253, 255);
pub const APPLE2_LIGHT_BLUE = Color.initRgba(208, 195, 255, 255);
pub const APPLE2_BROWN = Color.initRgba(96, 114, 3, 255);
pub const APPLE2_ORANGE = Color.initRgba(255, 106, 60, 255);
pub const APPLE2_GRAY2 = Color.initRgba(156, 156, 156, 255);
pub const APPLE2_PINK = Color.initRgba(255, 160, 208, 255);
pub const APPLE2_GREEN = Color.initRgba(20, 245, 60, 255);
pub const APPLE2_YELLOW = Color.initRgba(208, 221, 141, 255);
pub const APPLE2_AQUA = Color.initRgba(114, 255, 208, 255);
pub const APPLE2_WHITE = Color.initRgba(255, 255, 255, 255);

// ============================================================================
// VINTAGE PALETTES - MSX
// ============================================================================
pub const MSX_TRANSPARENT = Color.initRgba(0, 0, 0, 0);
pub const MSX_BLACK = Color.initRgba(0, 0, 0, 255);
pub const MSX_MEDIUM_GREEN = Color.initRgba(36, 219, 36, 255);
pub const MSX_LIGHT_GREEN = Color.initRgba(109, 255, 109, 255);
pub const MSX_DARK_BLUE = Color.initRgba(36, 36, 255, 255);
pub const MSX_LIGHT_BLUE = Color.initRgba(73, 109, 255, 255);
pub const MSX_DARK_RED = Color.initRgba(182, 36, 36, 255);
pub const MSX_CYAN = Color.initRgba(73, 219, 255, 255);
pub const MSX_MEDIUM_RED = Color.initRgba(255, 36, 36, 255);
pub const MSX_LIGHT_RED = Color.initRgba(255, 109, 109, 255);
pub const MSX_DARK_YELLOW = Color.initRgba(219, 219, 36, 255);
pub const MSX_LIGHT_YELLOW = Color.initRgba(219, 219, 146, 255);
pub const MSX_DARK_GREEN = Color.initRgba(36, 146, 36, 255);
pub const MSX_MAGENTA = Color.initRgba(219, 73, 182, 255);
pub const MSX_GRAY = Color.initRgba(182, 182, 182, 255);
pub const MSX_WHITE = Color.initRgba(255, 255, 255, 255);

// ============================================================================
// VINTAGE PALETTES - ZX SPECTRUM
// ============================================================================
pub const ZX_BLACK = Color.initRgba(0, 0, 0, 255);
pub const ZX_BLUE = Color.initRgba(0, 0, 215, 255);
pub const ZX_RED = Color.initRgba(215, 0, 0, 255);
pub const ZX_MAGENTA = Color.initRgba(215, 0, 215, 255);
pub const ZX_GREEN = Color.initRgba(0, 215, 0, 255);
pub const ZX_CYAN = Color.initRgba(0, 215, 215, 255);
pub const ZX_YELLOW = Color.initRgba(215, 215, 0, 255);
pub const ZX_WHITE = Color.initRgba(215, 215, 215, 255);
pub const ZX_BRIGHT_BLACK = Color.initRgba(0, 0, 0, 255);
pub const ZX_BRIGHT_BLUE = Color.initRgba(0, 0, 255, 255);
pub const ZX_BRIGHT_RED = Color.initRgba(255, 0, 0, 255);
pub const ZX_BRIGHT_MAGENTA = Color.initRgba(255, 0, 255, 255);
pub const ZX_BRIGHT_GREEN = Color.initRgba(0, 255, 0, 255);
pub const ZX_BRIGHT_CYAN = Color.initRgba(0, 255, 255, 255);
pub const ZX_BRIGHT_YELLOW = Color.initRgba(255, 255, 0, 255);
pub const ZX_BRIGHT_WHITE = Color.initRgba(255, 255, 255, 255);

// ============================================================================
// VINTAGE PALETTES - ATARI 2600
// ============================================================================
pub const ATARI_BLACK = Color.initRgba(0, 0, 0, 255);
pub const ATARI_GRAY_1 = Color.initRgba(68, 68, 68, 255);
pub const ATARI_GRAY_2 = Color.initRgba(124, 124, 124, 255);
pub const ATARI_WHITE = Color.initRgba(188, 188, 188, 255);
pub const ATARI_GOLD = Color.initRgba(136, 92, 0, 255);
pub const ATARI_ORANGE = Color.initRgba(180, 76, 0, 255);
pub const ATARI_BRIGHT_ORANGE = Color.initRgba(220, 92, 0, 255);
pub const ATARI_PINK = Color.initRgba(208, 68, 60, 255);
pub const ATARI_PURPLE = Color.initRgba(176, 56, 124, 255);
pub const ATARI_PURPLE_BLUE = Color.initRgba(132, 60, 172, 255);
pub const ATARI_BLUE_1 = Color.initRgba(80, 68, 196, 255);
pub const ATARI_BLUE_2 = Color.initRgba(36, 88, 200, 255);
pub const ATARI_LIGHT_BLUE = Color.initRgba(32, 116, 180, 255);
pub const ATARI_TURQUOISE = Color.initRgba(32, 140, 140, 255);
pub const ATARI_GREEN_BLUE = Color.initRgba(44, 156, 92, 255);
pub const ATARI_GREEN = Color.initRgba(60, 164, 36, 255);
pub const ATARI_YELLOW_GREEN = Color.initRgba(100, 164, 0, 255);

// ============================================================================
// VINTAGE PALETTES - SEGA MASTER SYSTEM
// ============================================================================
pub const SMS_BLACK = Color.initRgba(0, 0, 0, 255);
pub const SMS_DARK_BLUE = Color.initRgba(0, 0, 85, 255);
pub const SMS_BLUE = Color.initRgba(0, 0, 170, 255);
pub const SMS_LIGHT_BLUE = Color.initRgba(0, 0, 255, 255);
pub const SMS_DARK_GREEN = Color.initRgba(0, 85, 0, 255);
pub const SMS_GREEN = Color.initRgba(0, 170, 0, 255);
pub const SMS_LIGHT_GREEN = Color.initRgba(0, 255, 0, 255);
pub const SMS_DARK_CYAN = Color.initRgba(0, 85, 85, 255);
pub const SMS_CYAN = Color.initRgba(0, 170, 170, 255);
pub const SMS_LIGHT_CYAN = Color.initRgba(0, 255, 255, 255);
pub const SMS_DARK_RED = Color.initRgba(85, 0, 0, 255);
pub const SMS_RED = Color.initRgba(170, 0, 0, 255);
pub const SMS_LIGHT_RED = Color.initRgba(255, 0, 0, 255);
pub const SMS_DARK_MAGENTA = Color.initRgba(85, 0, 85, 255);
pub const SMS_MAGENTA = Color.initRgba(170, 0, 170, 255);
pub const SMS_LIGHT_MAGENTA = Color.initRgba(255, 0, 255, 255);
pub const SMS_DARK_YELLOW = Color.initRgba(85, 85, 0, 255);
pub const SMS_YELLOW = Color.initRgba(170, 170, 0, 255);
pub const SMS_LIGHT_YELLOW = Color.initRgba(255, 255, 0, 255);
pub const SMS_DARK_GRAY = Color.initRgba(85, 85, 85, 255);
pub const SMS_GRAY = Color.initRgba(170, 170, 170, 255);
pub const SMS_WHITE = Color.initRgba(255, 255, 255, 255);

// ============================================================================
// VINTAGE PALETTES - SEGA GENESIS / MEGA DRIVE
// ============================================================================
pub const GENESIS_BLACK = Color.initRgba(0, 0, 0, 255);
pub const GENESIS_DARK_GRAY = Color.initRgba(52, 52, 52, 255);
pub const GENESIS_GRAY = Color.initRgba(120, 120, 120, 255);
pub const GENESIS_LIGHT_GRAY = Color.initRgba(188, 188, 188, 255);
pub const GENESIS_WHITE = Color.initRgba(252, 252, 252, 255);
pub const GENESIS_DARK_RED = Color.initRgba(120, 0, 0, 255);
pub const GENESIS_RED = Color.initRgba(188, 52, 52, 255);
pub const GENESIS_LIGHT_RED = Color.initRgba(252, 120, 120, 255);
pub const GENESIS_DARK_ORANGE = Color.initRgba(120, 52, 0, 255);
pub const GENESIS_ORANGE = Color.initRgba(188, 120, 52, 255);
pub const GENESIS_YELLOW = Color.initRgba(252, 252, 120, 255);
pub const GENESIS_DARK_GREEN = Color.initRgba(0, 120, 0, 255);
pub const GENESIS_GREEN = Color.initRgba(52, 188, 52, 255);
pub const GENESIS_LIGHT_GREEN = Color.initRgba(120, 252, 120, 255);
pub const GENESIS_DARK_BLUE = Color.initRgba(0, 0, 120, 255);
pub const GENESIS_BLUE = Color.initRgba(52, 52, 188, 255);
pub const GENESIS_LIGHT_BLUE = Color.initRgba(120, 120, 252, 255);
pub const GENESIS_DARK_PURPLE = Color.initRgba(120, 0, 120, 255);
pub const GENESIS_PURPLE = Color.initRgba(188, 52, 188, 255);
pub const GENESIS_LIGHT_PURPLE = Color.initRgba(252, 120, 252, 255);

// ============================================================================
// ARTISTIC PALETTES - LOSPEC POPULAR
// ============================================================================
// Endesga 32
pub const ENDESGA_VOID = Color.initRgba(19, 19, 19, 255);
pub const ENDESGA_ASH = Color.initRgba(39, 39, 54, 255);
pub const ENDESGA_BLIND = Color.initRgba(81, 81, 81, 255);
pub const ENDESGA_IRON = Color.initRgba(140, 143, 174, 255);
pub const ENDESGA_LIGHT = Color.initRgba(222, 238, 214, 255);
pub const ENDESGA_WEED = Color.initRgba(49, 82, 49, 255);
pub const ENDESGA_SHAMROCK = Color.initRgba(87, 130, 84, 255);
pub const ENDESGA_CROCODILE = Color.initRgba(155, 173, 93, 255);
pub const ENDESGA_OCHER = Color.initRgba(205, 197, 105, 255);
pub const ENDESGA_SANDY = Color.initRgba(226, 198, 158, 255);
pub const ENDESGA_SKIN = Color.initRgba(229, 181, 143, 255);
pub const ENDESGA_FOX = Color.initRgba(200, 118, 76, 255);
pub const ENDESGA_BRICK = Color.initRgba(156, 72, 67, 255);
pub const ENDESGA_EDGE = Color.initRgba(117, 48, 56, 255);
pub const ENDESGA_BERRY = Color.initRgba(74, 35, 61, 255);
pub const ENDESGA_GRAPE = Color.initRgba(106, 55, 113, 255);
pub const ENDESGA_HEATHER = Color.initRgba(162, 97, 152, 255);
pub const ENDESGA_PETAL = Color.initRgba(222, 158, 178, 255);
pub const ENDESGA_BLOSSOM = Color.initRgba(244, 180, 187, 255);
pub const ENDESGA_SUNSET = Color.initRgba(255, 104, 112, 255);
pub const ENDESGA_EMBER = Color.initRgba(207, 71, 53, 255);
pub const ENDESGA_FIRE = Color.initRgba(250, 145, 64, 255);
pub const ENDESGA_SUN = Color.initRgba(255, 207, 85, 255);
pub const ENDESGA_BUTTER = Color.initRgba(254, 243, 192, 255);
pub const ENDESGA_AQUA = Color.initRgba(130, 229, 255, 255);
pub const ENDESGA_SPRAY = Color.initRgba(86, 182, 194, 255);
pub const ENDESGA_LAGOON = Color.initRgba(60, 132, 138, 255);
pub const ENDESGA_OCEAN = Color.initRgba(48, 89, 104, 255);
pub const ENDESGA_TRENCH = Color.initRgba(33, 56, 75, 255);
pub const ENDESGA_DEEP = Color.initRgba(24, 30, 42, 255);

// Resurrect 64
pub const R64_BLACK = Color.initRgba(46, 34, 47, 255);
pub const R64_DARK_PURPLE = Color.initRgba(62, 53, 70, 255);
pub const R64_PURPLE = Color.initRgba(98, 85, 101, 255);
pub const R64_LIGHT_PURPLE = Color.initRgba(150, 108, 108, 255);
pub const R64_BROWN = Color.initRgba(171, 97, 75, 255);
pub const R64_DARK_ORANGE = Color.initRgba(199, 114, 57, 255);
pub const R64_ORANGE = Color.initRgba(237, 148, 69, 255);
pub const R64_YELLOW = Color.initRgba(255, 204, 107, 255);
pub const R64_LIME = Color.initRgba(223, 224, 107, 255);
pub const R64_LIGHT_GREEN = Color.initRgba(169, 211, 108, 255);
pub const R64_GREEN = Color.initRgba(103, 191, 113, 255);
pub const R64_TEAL = Color.initRgba(73, 166, 154, 255);
pub const R64_CYAN = Color.initRgba(71, 192, 217, 255);
pub const R64_LIGHT_BLUE = Color.initRgba(137, 221, 255, 255);
pub const R64_WHITE = Color.initRgba(242, 255, 255, 255);
pub const R64_PINK = Color.initRgba(255, 178, 185, 255);
pub const R64_LIGHT_PINK = Color.initRgba(255, 139, 162, 255);
pub const R64_RED = Color.initRgba(227, 105, 112, 255);
pub const R64_DARK_RED = Color.initRgba(176, 75, 86, 255);
pub const R64_MAROON = Color.initRgba(134, 59, 84, 255);
pub const R64_PLUM = Color.initRgba(104, 56, 108, 255);

// ============================================================================
// ARTISTIC PALETTES - JAPANESE
// ============================================================================
// Traditional Japanese colors (Wa no iro)
pub const SHIRONERI = Color.initRgba(243, 243, 242, 255);
pub const GOFUN = Color.initRgba(255, 255, 252, 255);
pub const SHIRONEZUMI = Color.initRgba(185, 183, 178, 255);
pub const GINSHU = Color.initRgba(188, 45, 41, 255);
pub const BENIAKA = Color.initRgba(203, 76, 77, 255);
pub const SHINSHU = Color.initRgba(139, 36, 31, 255);
pub const ENJI = Color.initRgba(158, 43, 43, 255);
pub const SAKURA = Color.initRgba(254, 223, 225, 255);
pub const MOMO = Color.initRgba(244, 149, 155, 255);
pub const USUBENI = Color.initRgba(242, 102, 108, 255);
pub const SOHI = Color.initRgba(227, 92, 56, 255);
pub const HIWA = Color.initRgba(141, 178, 85, 255);
pub const MOEGI = Color.initRgba(144, 181, 114, 255);
pub const MATCHA = Color.initRgba(194, 193, 152, 255);
pub const ROKUSHO = Color.initRgba(71, 133, 133, 255);
pub const WASURENAGUSA = Color.initRgba(137, 195, 235, 255);
pub const HANADA = Color.initRgba(4, 79, 103, 255);
pub const RURI = Color.initRgba(31, 71, 136, 255);
pub const KONJOU = Color.initRgba(0, 49, 113, 255);
pub const AI = Color.initRgba(38, 67, 72, 255);
pub const SUMIRE = Color.initRgba(91, 50, 86, 255);
pub const FUJI = Color.initRgba(187, 169, 219, 255);
pub const MURASAKI = Color.initRgba(79, 40, 75, 255);
pub const KINCHA = Color.initRgba(198, 132, 61, 255);
pub const KITSUNE = Color.initRgba(152, 86, 41, 255);
pub const KURI = Color.initRgba(85, 46, 40, 255);
pub const TONOCHA = Color.initRgba(152, 116, 86, 255);
pub const NEZUMI = Color.initRgba(109, 109, 109, 255);
pub const SUMI = Color.initRgba(39, 34, 31, 255);

// ============================================================================
// ARTISTIC PALETTES - EARTH TONES
// ============================================================================
pub const UMBER_RAW = Color.initRgba(115, 74, 18, 255);
pub const UMBER_BURNT = Color.initRgba(138, 51, 36, 255);
pub const SIENNA_RAW = Color.initRgba(136, 75, 32, 255);
pub const SIENNA_BURNT = Color.initRgba(150, 64, 42, 255);
pub const OCHRE_YELLOW = Color.initRgba(204, 153, 0, 255);
pub const OCHRE_GOLD = Color.initRgba(207, 181, 59, 255);
pub const OCHRE_RED = Color.initRgba(194, 75, 64, 255);
pub const VERDIGRIS = Color.initRgba(67, 179, 174, 255);
pub const PRUSSIAN_BLUE = Color.initRgba(0, 49, 83, 255);
pub const ULTRAMARINE = Color.initRgba(18, 10, 143, 255);
pub const CERULEAN = Color.initRgba(0, 123, 167, 255);
pub const VIRIDIAN = Color.initRgba(64, 130, 109, 255);
pub const SAP_GREEN = Color.initRgba(80, 125, 42, 255);
pub const CHROME_GREEN = Color.initRgba(27, 77, 62, 255);
pub const CADMIUM_YELLOW = Color.initRgba(255, 246, 0, 255);
pub const CADMIUM_ORANGE = Color.initRgba(237, 135, 45, 255);
pub const CADMIUM_RED = Color.initRgba(227, 0, 34, 255);
pub const ALIZARIN_CRIMSON = Color.initRgba(227, 38, 54, 255);
pub const CARMINE = Color.initRgba(150, 0, 24, 255);
pub const VERMILION = Color.initRgba(227, 66, 52, 255);
pub const INDIAN_RED = Color.initRgba(205, 92, 92, 255);
pub const VENETIAN_RED = Color.initRgba(200, 8, 21, 255);
pub const NAPLES_YELLOW = Color.initRgba(250, 218, 94, 255);
pub const TITANIUM_WHITE = Color.initRgba(252, 255, 252, 255);
pub const ZINC_WHITE = Color.initRgba(253, 248, 255, 255);
pub const IVORY_BLACK = Color.initRgba(41, 36, 33, 255);
pub const LAMP_BLACK = Color.initRgba(42, 42, 42, 255);
pub const PAYNE_GRAY = Color.initRgba(83, 104, 120, 255);

// ============================================================================
// SCIENTIFIC & DATA VISUALIZATION
// ============================================================================
// Viridis
pub const VIRIDIS_0 = Color.initRgba(68, 1, 84, 255);
pub const VIRIDIS_1 = Color.initRgba(72, 36, 117, 255);
pub const VIRIDIS_2 = Color.initRgba(65, 68, 135, 255);
pub const VIRIDIS_3 = Color.initRgba(53, 95, 141, 255);
pub const VIRIDIS_4 = Color.initRgba(42, 120, 142, 255);
pub const VIRIDIS_5 = Color.initRgba(33, 145, 140, 255);
pub const VIRIDIS_6 = Color.initRgba(34, 168, 132, 255);
pub const VIRIDIS_7 = Color.initRgba(68, 191, 112, 255);
pub const VIRIDIS_8 = Color.initRgba(122, 209, 81, 255);
pub const VIRIDIS_9 = Color.initRgba(189, 223, 38, 255);
pub const VIRIDIS_10 = Color.initRgba(253, 231, 37, 255);

// Plasma
pub const PLASMA_0 = Color.initRgba(13, 8, 135, 255);
pub const PLASMA_1 = Color.initRgba(75, 3, 161, 255);
pub const PLASMA_2 = Color.initRgba(125, 3, 168, 255);
pub const PLASMA_3 = Color.initRgba(168, 34, 150, 255);
pub const PLASMA_4 = Color.initRgba(203, 70, 121, 255);
pub const PLASMA_5 = Color.initRgba(229, 107, 93, 255);
pub const PLASMA_6 = Color.initRgba(248, 148, 65, 255);
pub const PLASMA_7 = Color.initRgba(253, 195, 40, 255);
pub const PLASMA_8 = Color.initRgba(240, 249, 33, 255);

// Inferno
pub const INFERNO_0 = Color.initRgba(0, 0, 4, 255);
pub const INFERNO_1 = Color.initRgba(31, 12, 72, 255);
pub const INFERNO_2 = Color.initRgba(85, 15, 109, 255);
pub const INFERNO_3 = Color.initRgba(136, 34, 106, 255);
pub const INFERNO_4 = Color.initRgba(186, 54, 85, 255);
pub const INFERNO_5 = Color.initRgba(227, 89, 51, 255);
pub const INFERNO_6 = Color.initRgba(249, 140, 10, 255);
pub const INFERNO_7 = Color.initRgba(249, 201, 50, 255);
pub const INFERNO_8 = Color.initRgba(252, 255, 164, 255);

// Magma
pub const MAGMA_0 = Color.initRgba(0, 0, 4, 255);
pub const MAGMA_1 = Color.initRgba(28, 16, 68, 255);
pub const MAGMA_2 = Color.initRgba(79, 18, 123, 255);
pub const MAGMA_3 = Color.initRgba(129, 37, 129, 255);
pub const MAGMA_4 = Color.initRgba(181, 54, 122, 255);
pub const MAGMA_5 = Color.initRgba(229, 80, 100, 255);
pub const MAGMA_6 = Color.initRgba(251, 135, 97, 255);
pub const MAGMA_7 = Color.initRgba(254, 194, 135, 255);
pub const MAGMA_8 = Color.initRgba(252, 253, 191, 255);

// ============================================================================
// BRANDING COLORS - WEB/TECH
// ============================================================================
pub const TWITTER_BLUE = Color.initRgba(29, 161, 242, 255);
pub const FACEBOOK_BLUE = Color.initRgba(66, 103, 178, 255);
pub const INSTAGRAM_PINK = Color.initRgba(225, 48, 108, 255);
pub const INSTAGRAM_PURPLE = Color.initRgba(131, 58, 180, 255);
pub const INSTAGRAM_ORANGE = Color.initRgba(253, 89, 73, 255);
pub const LINKEDIN_BLUE = Color.initRgba(0, 119, 181, 255);
pub const YOUTUBE_RED = Color.initRgba(255, 0, 0, 255);
pub const SPOTIFY_GREEN = Color.initRgba(30, 215, 96, 255);
pub const TWITCH_PURPLE = Color.initRgba(100, 65, 165, 255);
pub const DISCORD_BLURPLE = Color.initRgba(88, 101, 242, 255);
pub const REDDIT_ORANGE = Color.initRgba(255, 87, 0, 255);
pub const SLACK_AUBERGINE = Color.initRgba(74, 21, 75, 255);
pub const SLACK_BLUE = Color.initRgba(54, 197, 240, 255);
pub const SLACK_GREEN = Color.initRgba(46, 182, 125, 255);
pub const SLACK_RED = Color.initRgba(224, 30, 90, 255);
pub const SLACK_YELLOW = Color.initRgba(236, 178, 46, 255);
pub const GITHUB_BLACK = Color.initRgba(36, 41, 46, 255);
pub const WHATSAPP_GREEN = Color.initRgba(37, 211, 102, 255);
pub const SNAPCHAT_YELLOW = Color.initRgba(255, 252, 0, 255);
pub const PINTEREST_RED = Color.initRgba(189, 8, 28, 255);
pub const TIKTOK_CYAN = Color.initRgba(37, 244, 238, 255);
pub const TIKTOK_PINK = Color.initRgba(254, 44, 85, 255);

// ============================================================================
// GAME ENGINE / TOOL DEFAULTS
// ============================================================================
pub const UNITY_GRAY = Color.initRgba(56, 56, 56, 255);
pub const UNITY_DARK = Color.initRgba(42, 42, 42, 255);
pub const UNITY_LIGHT = Color.initRgba(222, 222, 222, 255);
pub const UNITY_BLUE = Color.initRgba(62, 125, 231, 255);
pub const UNREAL_DARK = Color.initRgba(26, 26, 26, 255);
pub const UNREAL_GRAY = Color.initRgba(48, 48, 48, 255);
pub const UNREAL_BLUE = Color.initRgba(0, 122, 217, 255);
pub const GODOT_BLUE = Color.initRgba(72, 128, 185, 255);
pub const GODOT_DARK = Color.initRgba(37, 37, 37, 255);
pub const BLENDER_ORANGE = Color.initRgba(235, 122, 52, 255);
pub const BLENDER_DARK = Color.initRgba(35, 35, 35, 255);
pub const PHOTOSHOP_BLUE = Color.initRgba(49, 168, 255, 255);
pub const ILLUSTRATOR_ORANGE = Color.initRgba(255, 154, 0, 255);
pub const PREMIERE_PURPLE = Color.initRgba(150, 100, 255, 255);
pub const AFTEREFFECTS_PURPLE = Color.initRgba(213, 166, 255, 255);
pub const FIGMA_ORANGE = Color.initRgba(242, 78, 30, 255);
pub const FIGMA_PURPLE = Color.initRgba(162, 89, 255, 255);
pub const FIGMA_BLUE = Color.initRgba(24, 160, 251, 255);
pub const FIGMA_GREEN = Color.initRgba(10, 207, 131, 255);
pub const VSCODE_BLUE = Color.initRgba(0, 122, 204, 255);
pub const VSCODE_DARK = Color.initRgba(30, 30, 30, 255);

// ============================================================================
// SPORTS TEAM COLORS
// ============================================================================
pub const NFL_LEAGUE_BLUE = Color.initRgba(1, 51, 105, 255);
pub const NFL_LEAGUE_RED = Color.initRgba(210, 38, 48, 255);
pub const NBA_BLUE = Color.initRgba(23, 64, 139, 255);
pub const NBA_RED = Color.initRgba(200, 16, 46, 255);
pub const MLB_BLUE = Color.initRgba(0, 45, 114, 255);
pub const MLB_RED = Color.initRgba(191, 13, 62, 255);
pub const NHL_BLACK = Color.initRgba(0, 0, 0, 255);
pub const NHL_SILVER = Color.initRgba(165, 172, 175, 255);

// ============================================================================
// ANIMAL & WILDLIFE
// ============================================================================
pub const FUR_WHITE = Color.initRgba(250, 249, 246, 255);
pub const FUR_CREAM = Color.initRgba(255, 248, 220, 255);
pub const FUR_GOLDEN = Color.initRgba(218, 165, 32, 255);
pub const FUR_BROWN = Color.initRgba(139, 90, 43, 255);
pub const FUR_DARK_BROWN = Color.initRgba(92, 51, 23, 255);
pub const FUR_BLACK = Color.initRgba(25, 20, 20, 255);
pub const FUR_GRAY = Color.initRgba(140, 140, 130, 255);
pub const FUR_ORANGE = Color.initRgba(204, 85, 0, 255);
pub const FUR_RED = Color.initRgba(165, 42, 42, 255);
pub const FEATHER_WHITE = Color.initRgba(255, 255, 255, 255);
pub const FEATHER_BLACK = Color.initRgba(15, 15, 20, 255);
pub const FEATHER_BROWN = Color.initRgba(120, 80, 50, 255);
pub const FEATHER_BLUE = Color.initRgba(30, 144, 255, 255);
pub const FEATHER_RED = Color.initRgba(178, 34, 34, 255);
pub const FEATHER_YELLOW = Color.initRgba(255, 215, 0, 255);
pub const FEATHER_GREEN = Color.initRgba(34, 139, 34, 255);
pub const SCALE_GREEN = Color.initRgba(50, 100, 50, 255);
pub const SCALE_BROWN = Color.initRgba(100, 75, 50, 255);
pub const SCALE_YELLOW = Color.initRgba(200, 180, 80, 255);
pub const SCALE_BLUE = Color.initRgba(70, 130, 180, 255);
pub const SCALE_RED = Color.initRgba(165, 42, 42, 255);
pub const SCALE_BLACK = Color.initRgba(30, 30, 35, 255);
pub const FISH_SILVER = Color.initRgba(192, 192, 192, 255);
pub const FISH_GOLD = Color.initRgba(255, 194, 102, 255);
pub const FISH_ORANGE = Color.initRgba(255, 140, 0, 255);
pub const FISH_BLUE = Color.initRgba(0, 191, 255, 255);
pub const FISH_RED = Color.initRgba(220, 20, 60, 255);
pub const SHELL_TAN = Color.initRgba(210, 180, 140, 255);
pub const SHELL_PINK = Color.initRgba(255, 182, 193, 255);
pub const SHELL_BROWN = Color.initRgba(139, 69, 19, 255);
pub const SHELL_WHITE = Color.initRgba(255, 250, 240, 255);

// ============================================================================
// SPACE & COSMIC
// ============================================================================
pub const NEBULA_PINK = Color.initRgba(255, 102, 204, 255);
pub const NEBULA_PURPLE = Color.initRgba(138, 43, 226, 255);
pub const NEBULA_BLUE = Color.initRgba(65, 105, 225, 255);
pub const NEBULA_TEAL = Color.initRgba(0, 206, 209, 255);
pub const NEBULA_ORANGE = Color.initRgba(255, 140, 0, 255);
pub const NEBULA_RED = Color.initRgba(220, 20, 60, 255);
pub const STAR_WHITE = Color.initRgba(255, 255, 255, 255);
pub const STAR_YELLOW = Color.initRgba(255, 255, 200, 255);
pub const STAR_ORANGE = Color.initRgba(255, 200, 150, 255);
pub const STAR_RED = Color.initRgba(255, 150, 150, 255);
pub const STAR_BLUE = Color.initRgba(170, 200, 255, 255);
pub const BLACK_HOLE = Color.initRgba(5, 5, 10, 255);
pub const EVENT_HORIZON = Color.initRgba(255, 100, 50, 255);
pub const DARK_MATTER = Color.initRgba(30, 30, 50, 255);
pub const COSMIC_DUST = Color.initRgba(100, 100, 120, 255);
pub const SOLAR_FLARE = Color.initRgba(255, 200, 50, 255);
pub const MARS_RED = Color.initRgba(193, 68, 14, 255);
pub const MARS_DUST = Color.initRgba(210, 160, 140, 255);
pub const JUPITER_ORANGE = Color.initRgba(201, 144, 57, 255);
pub const JUPITER_BAND = Color.initRgba(168, 107, 57, 255);
pub const SATURN_GOLD = Color.initRgba(227, 190, 129, 255);
pub const SATURN_RING = Color.initRgba(189, 170, 140, 255);
pub const URANUS_CYAN = Color.initRgba(173, 216, 230, 255);
pub const NEPTUNE_BLUE = Color.initRgba(70, 130, 180, 255);
pub const PLUTO_TAN = Color.initRgba(200, 180, 160, 255);
pub const MOON_GRAY = Color.initRgba(150, 150, 150, 255);
pub const MOON_LIGHT = Color.initRgba(200, 200, 200, 255);
pub const MOON_DARK = Color.initRgba(80, 80, 80, 255);

// ============================================================================
// SEASONS
// ============================================================================
// Spring
pub const SPRING_GREEN = Color.initRgba(144, 238, 144, 255);
pub const SPRING_PINK = Color.initRgba(255, 182, 193, 255);
pub const SPRING_YELLOW = Color.initRgba(255, 255, 150, 255);
pub const SPRING_LAVENDER = Color.initRgba(230, 230, 250, 255);
pub const SPRING_SKY = Color.initRgba(135, 206, 250, 255);
// Summer
pub const SUMMER_BLUE = Color.initRgba(0, 191, 255, 255);
pub const SUMMER_GREEN = Color.initRgba(50, 205, 50, 255);
pub const SUMMER_YELLOW = Color.initRgba(255, 255, 0, 255);
pub const SUMMER_CORAL = Color.initRgba(255, 127, 80, 255);
pub const SUMMER_SAND = Color.initRgba(244, 238, 225, 255);
// Autumn
pub const AUTUMN_ORANGE = Color.initRgba(255, 140, 0, 255);
pub const AUTUMN_RED = Color.initRgba(178, 34, 34, 255);
pub const AUTUMN_BROWN = Color.initRgba(139, 90, 43, 255);
pub const AUTUMN_GOLD = Color.initRgba(218, 165, 32, 255);
pub const AUTUMN_MAROON = Color.initRgba(128, 0, 0, 255);
// Winter
pub const WINTER_WHITE = Color.initRgba(255, 250, 250, 255);
pub const WINTER_BLUE = Color.initRgba(176, 224, 230, 255);
pub const WINTER_SILVER = Color.initRgba(192, 192, 192, 255);
pub const WINTER_GRAY = Color.initRgba(128, 138, 135, 255);
pub const WINTER_EVERGREEN = Color.initRgba(0, 100, 0, 255);

// ============================================================================
// HOLIDAYS & CELEBRATIONS
// ============================================================================
// Christmas
pub const CHRISTMAS_RED = Color.initRgba(165, 0, 33, 255);
pub const CHRISTMAS_GREEN = Color.initRgba(0, 100, 0, 255);
pub const CHRISTMAS_GOLD = Color.initRgba(212, 175, 55, 255);
pub const CHRISTMAS_SILVER = Color.initRgba(192, 192, 192, 255);
pub const CHRISTMAS_WHITE = Color.initRgba(255, 250, 250, 255);
// Halloween
pub const HALLOWEEN_ORANGE = Color.initRgba(255, 117, 24, 255);
pub const HALLOWEEN_BLACK = Color.initRgba(20, 20, 20, 255);
pub const HALLOWEEN_PURPLE = Color.initRgba(75, 0, 130, 255);
pub const HALLOWEEN_GREEN = Color.initRgba(0, 255, 0, 255);
// Valentine
pub const VALENTINE_RED = Color.initRgba(220, 20, 60, 255);
pub const VALENTINE_PINK = Color.initRgba(255, 105, 180, 255);
pub const VALENTINE_WHITE = Color.initRgba(255, 255, 255, 255);
// Easter
pub const EASTER_PINK = Color.initRgba(255, 182, 193, 255);
pub const EASTER_YELLOW = Color.initRgba(255, 255, 150, 255);
pub const EASTER_BLUE = Color.initRgba(173, 216, 230, 255);
pub const EASTER_GREEN = Color.initRgba(152, 251, 152, 255);
pub const EASTER_LAVENDER = Color.initRgba(230, 230, 250, 255);
// St Patrick
pub const STPATRICK_GREEN = Color.initRgba(0, 158, 96, 255);
pub const STPATRICK_GOLD = Color.initRgba(255, 215, 0, 255);
// Independence Day (US)
pub const JULY4_RED = Color.initRgba(191, 10, 48, 255);
pub const JULY4_WHITE = Color.initRgba(255, 255, 255, 255);
pub const JULY4_BLUE = Color.initRgba(0, 40, 104, 255);

// ============================================================================
// MEDICAL & ANATOMICAL
// ============================================================================
pub const ARTERY_RED = Color.initRgba(200, 50, 50, 255);
pub const VEIN_BLUE = Color.initRgba(70, 90, 140, 255);
pub const MUSCLE_RED = Color.initRgba(140, 50, 60, 255);
pub const BONE_WHITE = Color.initRgba(235, 230, 220, 255);
pub const CARTILAGE = Color.initRgba(200, 200, 210, 255);
pub const NERVE_YELLOW = Color.initRgba(240, 220, 130, 255);
pub const FAT_YELLOW = Color.initRgba(255, 230, 160, 255);
pub const ORGAN_RED = Color.initRgba(150, 40, 60, 255);
pub const LIVER_BROWN = Color.initRgba(130, 70, 60, 255);
pub const LUNG_PINK = Color.initRgba(220, 180, 180, 255);
pub const BRAIN_GRAY = Color.initRgba(180, 170, 170, 255);
pub const TOOTH_WHITE = Color.initRgba(255, 250, 235, 255);
pub const TOOTH_YELLOW = Color.initRgba(250, 240, 200, 255);
pub const GUMS_PINK = Color.initRgba(230, 150, 150, 255);
pub const TONGUE_PINK = Color.initRgba(230, 140, 140, 255);
pub const IRIS_BROWN = Color.initRgba(130, 90, 60, 255);
pub const IRIS_BLUE = Color.initRgba(70, 130, 180, 255);
pub const IRIS_GREEN = Color.initRgba(90, 150, 100, 255);
pub const IRIS_GRAY = Color.initRgba(140, 150, 160, 255);
pub const SCLERA = Color.initRgba(255, 255, 250, 255);
pub const PUPIL = Color.initRgba(20, 20, 20, 255);

// ============================================================================
// POISON & TOXIC (Expanded)
// ============================================================================
pub const TOXIC_YELLOW = Color.initRgba(255, 255, 0, 255);
pub const TOXIC_PURPLE = Color.initRgba(128, 0, 128, 255);
pub const RADIOACTIVE_GREEN = Color.initRgba(127, 255, 0, 255);
pub const BIOHAZARD_ORANGE = Color.initRgba(255, 152, 0, 255);
pub const CHEMICAL_BLUE = Color.initRgba(0, 150, 255, 255);
pub const CORROSIVE_YELLOW = Color.initRgba(255, 193, 7, 255);
pub const POISON_PURPLE = Color.initRgba(75, 0, 130, 255);
pub const VENOM_GREEN = Color.initRgba(50, 150, 50, 255);
pub const PLAGUE_BROWN = Color.initRgba(100, 80, 50, 255);
pub const MIASMA_GRAY = Color.initRgba(100, 110, 100, 255);

// ============================================================================
// STEAMPUNK
// ============================================================================
pub const STEAM_BRASS = Color.initRgba(181, 166, 66, 255);
pub const STEAM_COPPER = Color.initRgba(184, 115, 51, 255);
pub const STEAM_BRONZE = Color.initRgba(205, 127, 50, 255);
pub const STEAM_IRON = Color.initRgba(82, 82, 82, 255);
pub const STEAM_RUST = Color.initRgba(183, 65, 14, 255);
pub const STEAM_LEATHER = Color.initRgba(102, 68, 40, 255);
pub const STEAM_WOOD = Color.initRgba(139, 90, 43, 255);
pub const STEAM_IVORY = Color.initRgba(255, 255, 240, 255);
pub const STEAM_COAL = Color.initRgba(35, 35, 35, 255);
pub const STEAM_SMOKE = Color.initRgba(128, 128, 128, 255);
pub const STEAM_GLASS = Color.initRgba(200, 225, 235, 200);
pub const STEAM_GAUGE = Color.initRgba(220, 220, 200, 255);

// ============================================================================
// CYBERPUNK
// ============================================================================
pub const CYBER_BLACK = Color.initRgba(10, 10, 15, 255);
pub const CYBER_DARK_GRAY = Color.initRgba(30, 30, 40, 255);
pub const CYBER_NEON_PINK = Color.initRgba(255, 20, 147, 255);
pub const CYBER_NEON_BLUE = Color.initRgba(0, 255, 255, 255);
pub const CYBER_NEON_PURPLE = Color.initRgba(191, 0, 255, 255);
pub const CYBER_NEON_GREEN = Color.initRgba(57, 255, 20, 255);
pub const CYBER_NEON_YELLOW = Color.initRgba(255, 255, 0, 255);
pub const CYBER_NEON_ORANGE = Color.initRgba(255, 95, 31, 255);
pub const CYBER_CHROME = Color.initRgba(219, 226, 233, 255);
pub const CYBER_DARK_BLUE = Color.initRgba(20, 30, 60, 255);
pub const CYBER_DARK_PURPLE = Color.initRgba(40, 20, 60, 255);
pub const CYBER_RAIN = Color.initRgba(100, 150, 200, 150);

// ============================================================================
// SYNTHWAVE / OUTRUN
// ============================================================================
pub const SYNTH_BLACK = Color.initRgba(10, 5, 20, 255);
pub const SYNTH_DARK_PURPLE = Color.initRgba(30, 10, 60, 255);
pub const SYNTH_PURPLE = Color.initRgba(80, 40, 120, 255);
pub const SYNTH_PINK = Color.initRgba(255, 113, 206, 255);
pub const SYNTH_HOT_PINK = Color.initRgba(255, 16, 240, 255);
pub const SYNTH_CYAN = Color.initRgba(5, 255, 255, 255);
pub const SYNTH_BLUE = Color.initRgba(1, 205, 254, 255);
pub const SYNTH_ORANGE = Color.initRgba(255, 95, 31, 255);
pub const SYNTH_YELLOW = Color.initRgba(255, 211, 25, 255);
pub const SYNTH_GRID = Color.initRgba(180, 70, 255, 255);
pub const SYNTH_SUN_TOP = Color.initRgba(255, 154, 0, 255);
pub const SYNTH_SUN_BOTTOM = Color.initRgba(255, 50, 100, 255);
pub const SYNTH_HORIZON = Color.initRgba(20, 0, 40, 255);

// ============================================================================
// VAPORWAVE
// ============================================================================
pub const VAPOR_DARK = Color.initRgba(20, 10, 30, 255);
pub const VAPOR_TEAL = Color.initRgba(115, 235, 235, 255);
pub const VAPOR_MAGENTA = Color.initRgba(255, 110, 199, 255);
pub const VAPOR_LAVENDER = Color.initRgba(190, 145, 255, 255);
pub const VAPOR_PEACH = Color.initRgba(255, 200, 180, 255);
pub const VAPOR_MINT = Color.initRgba(170, 255, 200, 255);
pub const VAPOR_CORAL = Color.initRgba(255, 150, 150, 255);
pub const VAPOR_SKY = Color.initRgba(135, 200, 255, 255);
pub const VAPOR_MARBLE = Color.initRgba(230, 230, 235, 255);
pub const VAPOR_STATUE = Color.initRgba(200, 200, 210, 255);
pub const VAPOR_PALM = Color.initRgba(0, 150, 100, 255);
pub const VAPOR_GRID = Color.initRgba(255, 100, 255, 255);

// ============================================================================
// MILITARY / CAMOUFLAGE
// ============================================================================
pub const CAMO_OLIVE = Color.initRgba(107, 142, 35, 255);
pub const CAMO_TAN = Color.initRgba(210, 180, 140, 255);
pub const CAMO_BROWN = Color.initRgba(101, 67, 33, 255);
pub const CAMO_BLACK = Color.initRgba(30, 30, 30, 255);
pub const CAMO_DARK_GREEN = Color.initRgba(47, 79, 47, 255);
pub const CAMO_SAND = Color.initRgba(194, 178, 128, 255);
pub const CAMO_GRAY = Color.initRgba(128, 128, 128, 255);
pub const CAMO_WHITE = Color.initRgba(245, 245, 245, 255);
pub const NAVY_BLUE = Color.initRgba(0, 0, 128, 255);
pub const ARMY_GREEN = Color.initRgba(75, 83, 32, 255);
pub const AIR_FORCE_BLUE = Color.initRgba(93, 138, 168, 255);
pub const MARINE_RED = Color.initRgba(128, 0, 0, 255);
pub const KHAKI = Color.initRgba(195, 176, 145, 255);
pub const OLIVE_DRAB = Color.initRgba(107, 142, 35, 255);
pub const FIELD_GRAY = Color.initRgba(108, 128, 109, 255);

// ============================================================================
// SPECIAL EFFECTS
// ============================================================================
pub const LIGHTNING_WHITE = Color.initRgba(255, 255, 255, 255);
pub const LIGHTNING_BLUE = Color.initRgba(200, 200, 255, 255);
pub const LIGHTNING_PURPLE = Color.initRgba(200, 150, 255, 255);
pub const SPARK_YELLOW = Color.initRgba(255, 255, 150, 255);
pub const SPARK_ORANGE = Color.initRgba(255, 200, 100, 255);
pub const ELECTRICITY_BLUE = Color.initRgba(100, 200, 255, 255);
pub const PLASMA_PURPLE = Color.initRgba(180, 100, 255, 255);
pub const PLASMA_PINK = Color.initRgba(255, 100, 200, 255);
pub const HEAL_GREEN = Color.initRgba(100, 255, 100, 255);
pub const DAMAGE_RED = Color.initRgba(255, 50, 50, 255);
pub const SHIELD_BLUE = Color.initRgba(100, 150, 255, 150);
pub const BUFF_GOLD = Color.initRgba(255, 215, 0, 255);
pub const DEBUFF_PURPLE = Color.initRgba(150, 50, 200, 255);
pub const FREEZE_BLUE = Color.initRgba(150, 220, 255, 255);
pub const BURN_ORANGE = Color.initRgba(255, 130, 0, 255);
pub const STUN_YELLOW = Color.initRgba(255, 255, 100, 255);
pub const SLOW_CYAN = Color.initRgba(100, 200, 200, 255);
pub const HASTE_GREEN = Color.initRgba(150, 255, 100, 255);
pub const INVISIBILITY = Color.initRgba(200, 200, 255, 100);
pub const TELEPORT_PURPLE = Color.initRgba(200, 100, 255, 200);
pub const EXPLOSION_ORANGE = Color.initRgba(255, 150, 50, 255);
pub const EXPLOSION_YELLOW = Color.initRgba(255, 255, 100, 255);
pub const EXPLOSION_RED = Color.initRgba(255, 50, 0, 255);
pub const SMOKE_LIGHT = Color.initRgba(180, 180, 180, 200);
pub const SMOKE_DARK = Color.initRgba(80, 80, 80, 200);
pub const DUST_CLOUD = Color.initRgba(160, 140, 100, 180);

// ============================================================================
// NHL TEAM COLORS
// ============================================================================
// Atlantic Division
pub const NHL_BRUINS_GOLD = Color.initRgba(252, 181, 20, 255);
pub const NHL_BRUINS_BLACK = Color.initRgba(17, 17, 17, 255);
pub const NHL_SABRES_NAVY = Color.initRgba(0, 38, 84, 255);
pub const NHL_SABRES_GOLD = Color.initRgba(252, 181, 20, 255);
pub const NHL_RED_WINGS_RED = Color.initRgba(206, 17, 38, 255);
pub const NHL_RED_WINGS_WHITE = Color.initRgba(255, 255, 255, 255);
pub const NHL_PANTHERS_RED = Color.initRgba(200, 16, 46, 255);
pub const NHL_PANTHERS_NAVY = Color.initRgba(4, 30, 66, 255);
pub const NHL_PANTHERS_GOLD = Color.initRgba(185, 151, 91, 255);
pub const NHL_CANADIENS_RED = Color.initRgba(175, 30, 45, 255);
pub const NHL_CANADIENS_BLUE = Color.initRgba(25, 33, 104, 255);
pub const NHL_SENATORS_RED = Color.initRgba(200, 16, 46, 255);
pub const NHL_SENATORS_BLACK = Color.initRgba(0, 0, 0, 255);
pub const NHL_SENATORS_GOLD = Color.initRgba(198, 146, 20, 255);
pub const NHL_LIGHTNING_BLUE = Color.initRgba(0, 40, 104, 255);
pub const NHL_LIGHTNING_WHITE = Color.initRgba(255, 255, 255, 255);
pub const NHL_MAPLE_LEAFS_BLUE = Color.initRgba(0, 32, 91, 255);
pub const NHL_MAPLE_LEAFS_WHITE = Color.initRgba(255, 255, 255, 255);
// Metropolitan Division
pub const NHL_HURRICANES_RED = Color.initRgba(206, 17, 38, 255);
pub const NHL_HURRICANES_BLACK = Color.initRgba(0, 0, 0, 255);
pub const NHL_BLUE_JACKETS_NAVY = Color.initRgba(0, 38, 84, 255);
pub const NHL_BLUE_JACKETS_RED = Color.initRgba(206, 17, 38, 255);
pub const NHL_DEVILS_RED = Color.initRgba(206, 17, 38, 255);
pub const NHL_DEVILS_BLACK = Color.initRgba(0, 0, 0, 255);
pub const NHL_ISLANDERS_ORANGE = Color.initRgba(244, 125, 48, 255);
pub const NHL_ISLANDERS_BLUE = Color.initRgba(0, 83, 155, 255);
pub const NHL_RANGERS_BLUE = Color.initRgba(0, 56, 168, 255);
pub const NHL_RANGERS_RED = Color.initRgba(206, 17, 38, 255);
pub const NHL_FLYERS_ORANGE = Color.initRgba(247, 73, 2, 255);
pub const NHL_FLYERS_BLACK = Color.initRgba(0, 0, 0, 255);
pub const NHL_PENGUINS_BLACK = Color.initRgba(0, 0, 0, 255);
pub const NHL_PENGUINS_GOLD = Color.initRgba(252, 181, 20, 255);
pub const NHL_CAPITALS_RED = Color.initRgba(200, 16, 46, 255);
pub const NHL_CAPITALS_NAVY = Color.initRgba(4, 30, 66, 255);
// Central Division
pub const NHL_BLACKHAWKS_RED = Color.initRgba(207, 10, 44, 255);
pub const NHL_BLACKHAWKS_BLACK = Color.initRgba(0, 0, 0, 255);
pub const NHL_AVALANCHE_BURGUNDY = Color.initRgba(111, 38, 61, 255);
pub const NHL_AVALANCHE_BLUE = Color.initRgba(35, 97, 146, 255);
pub const NHL_STARS_GREEN = Color.initRgba(0, 104, 71, 255);
pub const NHL_STARS_SILVER = Color.initRgba(143, 143, 140, 255);
pub const NHL_WILD_GREEN = Color.initRgba(2, 73, 48, 255);
pub const NHL_WILD_RED = Color.initRgba(175, 35, 36, 255);
pub const NHL_PREDATORS_GOLD = Color.initRgba(255, 184, 28, 255);
pub const NHL_PREDATORS_NAVY = Color.initRgba(4, 30, 66, 255);
pub const NHL_BLUES_BLUE = Color.initRgba(0, 47, 135, 255);
pub const NHL_BLUES_GOLD = Color.initRgba(252, 181, 20, 255);
pub const NHL_JETS_NAVY = Color.initRgba(4, 30, 66, 255);
pub const NHL_JETS_BLUE = Color.initRgba(0, 76, 151, 255);
pub const NHL_UTAH_BLUE = Color.initRgba(0, 90, 156, 255);
pub const NHL_UTAH_BLACK = Color.initRgba(0, 0, 0, 255);
// Pacific Division
pub const NHL_DUCKS_ORANGE = Color.initRgba(252, 76, 2, 255);
pub const NHL_DUCKS_BLACK = Color.initRgba(0, 0, 0, 255);
pub const NHL_DUCKS_GOLD = Color.initRgba(181, 152, 98, 255);
pub const NHL_FLAMES_RED = Color.initRgba(200, 16, 46, 255);
pub const NHL_FLAMES_GOLD = Color.initRgba(241, 190, 72, 255);
pub const NHL_OILERS_ORANGE = Color.initRgba(252, 76, 2, 255);
pub const NHL_OILERS_NAVY = Color.initRgba(4, 30, 66, 255);
pub const NHL_KINGS_BLACK = Color.initRgba(17, 17, 17, 255);
pub const NHL_KINGS_SILVER = Color.initRgba(162, 170, 173, 255);
pub const NHL_SHARKS_TEAL = Color.initRgba(0, 109, 117, 255);
pub const NHL_SHARKS_BLACK = Color.initRgba(0, 0, 0, 255);
pub const NHL_KRAKEN_BLUE = Color.initRgba(0, 22, 40, 255);
pub const NHL_KRAKEN_TEAL = Color.initRgba(153, 217, 217, 255);
pub const NHL_KRAKEN_RED = Color.initRgba(232, 6, 69, 255);
pub const NHL_CANUCKS_BLUE = Color.initRgba(0, 32, 91, 255);
pub const NHL_CANUCKS_GREEN = Color.initRgba(10, 134, 61, 255);
pub const NHL_GOLDEN_KNIGHTS_GOLD = Color.initRgba(185, 151, 91, 255);
pub const NHL_GOLDEN_KNIGHTS_BLACK = Color.initRgba(51, 63, 66, 255);
pub const NHL_GOLDEN_KNIGHTS_RED = Color.initRgba(200, 16, 46, 255);

// ============================================================================
// NBA TEAM COLORS
// ============================================================================
// Eastern Conference - Atlantic
pub const NBA_CELTICS_GREEN = Color.initRgba(0, 122, 51, 255);
pub const NBA_CELTICS_GOLD = Color.initRgba(139, 111, 78, 255);
pub const NBA_NETS_BLACK = Color.initRgba(0, 0, 0, 255);
pub const NBA_NETS_WHITE = Color.initRgba(255, 255, 255, 255);
pub const NBA_KNICKS_ORANGE = Color.initRgba(245, 132, 38, 255);
pub const NBA_KNICKS_BLUE = Color.initRgba(0, 107, 182, 255);
pub const NBA_76ERS_BLUE = Color.initRgba(0, 107, 182, 255);
pub const NBA_76ERS_RED = Color.initRgba(237, 23, 76, 255);
pub const NBA_RAPTORS_RED = Color.initRgba(206, 17, 65, 255);
pub const NBA_RAPTORS_BLACK = Color.initRgba(6, 25, 34, 255);
pub const NBA_RAPTORS_GOLD = Color.initRgba(180, 151, 90, 255);
// Eastern Conference - Central
pub const NBA_BULLS_RED = Color.initRgba(206, 17, 65, 255);
pub const NBA_BULLS_BLACK = Color.initRgba(6, 25, 34, 255);
pub const NBA_CAVALIERS_WINE = Color.initRgba(134, 0, 56, 255);
pub const NBA_CAVALIERS_GOLD = Color.initRgba(253, 187, 48, 255);
pub const NBA_PISTONS_RED = Color.initRgba(200, 16, 46, 255);
pub const NBA_PISTONS_BLUE = Color.initRgba(29, 66, 138, 255);
pub const NBA_PACERS_GOLD = Color.initRgba(253, 187, 48, 255);
pub const NBA_PACERS_NAVY = Color.initRgba(0, 45, 98, 255);
pub const NBA_BUCKS_GREEN = Color.initRgba(0, 71, 27, 255);
pub const NBA_BUCKS_CREAM = Color.initRgba(240, 235, 210, 255);
// Eastern Conference - Southeast
pub const NBA_HAWKS_RED = Color.initRgba(225, 68, 52, 255);
pub const NBA_HAWKS_BLACK = Color.initRgba(0, 0, 0, 255);
pub const NBA_HORNETS_TEAL = Color.initRgba(29, 17, 96, 255);
pub const NBA_HORNETS_PURPLE = Color.initRgba(0, 120, 140, 255);
pub const NBA_HEAT_RED = Color.initRgba(152, 0, 46, 255);
pub const NBA_HEAT_BLACK = Color.initRgba(0, 0, 0, 255);
pub const NBA_HEAT_YELLOW = Color.initRgba(249, 160, 27, 255);
pub const NBA_MAGIC_BLUE = Color.initRgba(0, 125, 197, 255);
pub const NBA_MAGIC_BLACK = Color.initRgba(0, 0, 0, 255);
pub const NBA_WIZARDS_NAVY = Color.initRgba(0, 43, 92, 255);
pub const NBA_WIZARDS_RED = Color.initRgba(227, 24, 55, 255);
// Western Conference - Northwest
pub const NBA_NUGGETS_NAVY = Color.initRgba(13, 34, 64, 255);
pub const NBA_NUGGETS_GOLD = Color.initRgba(255, 198, 39, 255);
pub const NBA_TIMBERWOLVES_NAVY = Color.initRgba(12, 35, 64, 255);
pub const NBA_TIMBERWOLVES_GREEN = Color.initRgba(35, 97, 146, 255);
pub const NBA_THUNDER_BLUE = Color.initRgba(0, 125, 195, 255);
pub const NBA_THUNDER_ORANGE = Color.initRgba(239, 59, 36, 255);
pub const NBA_BLAZERS_RED = Color.initRgba(224, 58, 62, 255);
pub const NBA_BLAZERS_BLACK = Color.initRgba(6, 25, 34, 255);
pub const NBA_JAZZ_NAVY = Color.initRgba(0, 43, 92, 255);
pub const NBA_JAZZ_YELLOW = Color.initRgba(249, 160, 27, 255);
pub const NBA_JAZZ_GREEN = Color.initRgba(0, 71, 27, 255);
// Western Conference - Pacific
pub const NBA_WARRIORS_BLUE = Color.initRgba(29, 66, 138, 255);
pub const NBA_WARRIORS_GOLD = Color.initRgba(255, 199, 44, 255);
pub const NBA_CLIPPERS_RED = Color.initRgba(200, 16, 46, 255);
pub const NBA_CLIPPERS_BLUE = Color.initRgba(29, 66, 148, 255);
pub const NBA_LAKERS_PURPLE = Color.initRgba(85, 37, 130, 255);
pub const NBA_LAKERS_GOLD = Color.initRgba(253, 185, 39, 255);
pub const NBA_SUNS_ORANGE = Color.initRgba(229, 95, 32, 255);
pub const NBA_SUNS_PURPLE = Color.initRgba(29, 17, 96, 255);
pub const NBA_KINGS_PURPLE = Color.initRgba(91, 43, 130, 255);
pub const NBA_KINGS_GRAY = Color.initRgba(99, 113, 122, 255);
// Western Conference - Southwest
pub const NBA_MAVERICKS_BLUE = Color.initRgba(0, 83, 188, 255);
pub const NBA_MAVERICKS_NAVY = Color.initRgba(0, 43, 92, 255);
pub const NBA_ROCKETS_RED = Color.initRgba(206, 17, 65, 255);
pub const NBA_ROCKETS_BLACK = Color.initRgba(6, 25, 34, 255);
pub const NBA_GRIZZLIES_NAVY = Color.initRgba(93, 118, 169, 255);
pub const NBA_GRIZZLIES_BLUE = Color.initRgba(18, 23, 63, 255);
pub const NBA_PELICANS_NAVY = Color.initRgba(0, 22, 65, 255);
pub const NBA_PELICANS_GOLD = Color.initRgba(180, 151, 90, 255);
pub const NBA_PELICANS_RED = Color.initRgba(227, 24, 55, 255);
pub const NBA_SPURS_BLACK = Color.initRgba(0, 0, 0, 255);
pub const NBA_SPURS_SILVER = Color.initRgba(196, 206, 211, 255);

// ============================================================================
// MLB TEAM COLORS
// ============================================================================
// American League East
pub const MLB_ORIOLES_ORANGE = Color.initRgba(223, 70, 1, 255);
pub const MLB_ORIOLES_BLACK = Color.initRgba(0, 0, 0, 255);
pub const MLB_RED_SOX_RED = Color.initRgba(189, 48, 57, 255);
pub const MLB_RED_SOX_NAVY = Color.initRgba(12, 35, 64, 255);
pub const MLB_YANKEES_NAVY = Color.initRgba(12, 35, 64, 255);
pub const MLB_YANKEES_WHITE = Color.initRgba(255, 255, 255, 255);
pub const MLB_RAYS_NAVY = Color.initRgba(9, 44, 92, 255);
pub const MLB_RAYS_BLUE = Color.initRgba(143, 188, 230, 255);
pub const MLB_RAYS_GOLD = Color.initRgba(249, 183, 0, 255);
pub const MLB_BLUE_JAYS_BLUE = Color.initRgba(19, 74, 142, 255);
pub const MLB_BLUE_JAYS_NAVY = Color.initRgba(29, 45, 68, 255);
pub const MLB_BLUE_JAYS_RED = Color.initRgba(232, 41, 28, 255);
// American League Central
pub const MLB_WHITE_SOX_BLACK = Color.initRgba(39, 37, 31, 255);
pub const MLB_WHITE_SOX_SILVER = Color.initRgba(196, 206, 211, 255);
pub const MLB_GUARDIANS_RED = Color.initRgba(227, 25, 55, 255);
pub const MLB_GUARDIANS_NAVY = Color.initRgba(12, 35, 64, 255);
pub const MLB_TIGERS_NAVY = Color.initRgba(12, 35, 64, 255);
pub const MLB_TIGERS_ORANGE = Color.initRgba(250, 70, 22, 255);
pub const MLB_ROYALS_BLUE = Color.initRgba(0, 70, 135, 255);
pub const MLB_ROYALS_GOLD = Color.initRgba(189, 155, 96, 255);
pub const MLB_TWINS_RED = Color.initRgba(211, 17, 69, 255);
pub const MLB_TWINS_NAVY = Color.initRgba(0, 43, 92, 255);
// American League West
pub const MLB_ASTROS_ORANGE = Color.initRgba(235, 110, 31, 255);
pub const MLB_ASTROS_NAVY = Color.initRgba(0, 45, 98, 255);
pub const MLB_ANGELS_RED = Color.initRgba(186, 0, 33, 255);
pub const MLB_ANGELS_NAVY = Color.initRgba(0, 50, 99, 255);
pub const MLB_ATHLETICS_GREEN = Color.initRgba(0, 56, 49, 255);
pub const MLB_ATHLETICS_GOLD = Color.initRgba(239, 178, 30, 255);
pub const MLB_MARINERS_NAVY = Color.initRgba(12, 44, 86, 255);
pub const MLB_MARINERS_TEAL = Color.initRgba(0, 92, 92, 255);
pub const MLB_RANGERS_BLUE = Color.initRgba(0, 50, 120, 255);
pub const MLB_RANGERS_RED = Color.initRgba(192, 17, 31, 255);
// National League East
pub const MLB_BRAVES_NAVY = Color.initRgba(19, 39, 79, 255);
pub const MLB_BRAVES_RED = Color.initRgba(206, 17, 65, 255);
pub const MLB_MARLINS_BLACK = Color.initRgba(0, 0, 0, 255);
pub const MLB_MARLINS_BLUE = Color.initRgba(0, 163, 224, 255);
pub const MLB_MARLINS_RED = Color.initRgba(239, 51, 64, 255);
pub const MLB_METS_ORANGE = Color.initRgba(252, 89, 16, 255);
pub const MLB_METS_BLUE = Color.initRgba(0, 45, 114, 255);
pub const MLB_PHILLIES_RED = Color.initRgba(232, 24, 40, 255);
pub const MLB_PHILLIES_BLUE = Color.initRgba(40, 72, 152, 255);
pub const MLB_NATIONALS_RED = Color.initRgba(171, 0, 3, 255);
pub const MLB_NATIONALS_NAVY = Color.initRgba(20, 34, 90, 255);
// National League Central
pub const MLB_CUBS_BLUE = Color.initRgba(14, 51, 134, 255);
pub const MLB_CUBS_RED = Color.initRgba(204, 52, 51, 255);
pub const MLB_REDS_RED = Color.initRgba(198, 1, 31, 255);
pub const MLB_REDS_BLACK = Color.initRgba(0, 0, 0, 255);
pub const MLB_BREWERS_NAVY = Color.initRgba(18, 40, 75, 255);
pub const MLB_BREWERS_GOLD = Color.initRgba(182, 146, 46, 255);
pub const MLB_PIRATES_BLACK = Color.initRgba(39, 37, 31, 255);
pub const MLB_PIRATES_GOLD = Color.initRgba(253, 184, 39, 255);
pub const MLB_CARDINALS_RED = Color.initRgba(196, 30, 58, 255);
pub const MLB_CARDINALS_NAVY = Color.initRgba(12, 35, 64, 255);
// National League West
pub const MLB_DIAMONDBACKS_RED = Color.initRgba(167, 25, 48, 255);
pub const MLB_DIAMONDBACKS_TEAL = Color.initRgba(30, 107, 107, 255);
pub const MLB_DIAMONDBACKS_SAND = Color.initRgba(227, 212, 173, 255);
pub const MLB_ROCKIES_PURPLE = Color.initRgba(51, 0, 111, 255);
pub const MLB_ROCKIES_BLACK = Color.initRgba(0, 0, 0, 255);
pub const MLB_ROCKIES_SILVER = Color.initRgba(196, 206, 211, 255);
pub const MLB_DODGERS_BLUE = Color.initRgba(0, 90, 156, 255);
pub const MLB_DODGERS_RED = Color.initRgba(239, 62, 66, 255);
pub const MLB_PADRES_BROWN = Color.initRgba(47, 36, 28, 255);
pub const MLB_PADRES_GOLD = Color.initRgba(255, 196, 37, 255);
pub const MLB_GIANTS_ORANGE = Color.initRgba(253, 90, 30, 255);
pub const MLB_GIANTS_BLACK = Color.initRgba(39, 37, 31, 255);
pub const MLB_GIANTS_CREAM = Color.initRgba(238, 220, 197, 255);

// ============================================================================
// NFL TEAM COLORS
// ============================================================================
// AFC East
pub const NFL_BILLS_BLUE = Color.initRgba(0, 51, 141, 255);
pub const NFL_BILLS_RED = Color.initRgba(198, 12, 48, 255);
pub const NFL_DOLPHINS_AQUA = Color.initRgba(0, 142, 151, 255);
pub const NFL_DOLPHINS_ORANGE = Color.initRgba(252, 76, 2, 255);
pub const NFL_PATRIOTS_NAVY = Color.initRgba(0, 34, 68, 255);
pub const NFL_PATRIOTS_RED = Color.initRgba(198, 12, 48, 255);
pub const NFL_PATRIOTS_SILVER = Color.initRgba(176, 186, 188, 255);
pub const NFL_JETS_GREEN = Color.initRgba(18, 87, 64, 255);
pub const NFL_JETS_WHITE = Color.initRgba(255, 255, 255, 255);
// AFC North
pub const NFL_RAVENS_PURPLE = Color.initRgba(36, 23, 115, 255);
pub const NFL_RAVENS_BLACK = Color.initRgba(0, 0, 0, 255);
pub const NFL_RAVENS_GOLD = Color.initRgba(158, 124, 12, 255);
pub const NFL_BENGALS_ORANGE = Color.initRgba(251, 79, 20, 255);
pub const NFL_BENGALS_BLACK = Color.initRgba(0, 0, 0, 255);
pub const NFL_BROWNS_ORANGE = Color.initRgba(255, 60, 0, 255);
pub const NFL_BROWNS_BROWN = Color.initRgba(49, 29, 0, 255);
pub const NFL_STEELERS_BLACK = Color.initRgba(16, 24, 32, 255);
pub const NFL_STEELERS_GOLD = Color.initRgba(255, 182, 18, 255);
// AFC South
pub const NFL_TEXANS_NAVY = Color.initRgba(3, 32, 47, 255);
pub const NFL_TEXANS_RED = Color.initRgba(167, 25, 48, 255);
pub const NFL_COLTS_BLUE = Color.initRgba(0, 44, 95, 255);
pub const NFL_COLTS_WHITE = Color.initRgba(255, 255, 255, 255);
pub const NFL_JAGUARS_TEAL = Color.initRgba(0, 103, 120, 255);
pub const NFL_JAGUARS_BLACK = Color.initRgba(16, 24, 32, 255);
pub const NFL_JAGUARS_GOLD = Color.initRgba(159, 121, 44, 255);
pub const NFL_TITANS_NAVY = Color.initRgba(12, 35, 64, 255);
pub const NFL_TITANS_BLUE = Color.initRgba(75, 146, 219, 255);
pub const NFL_TITANS_RED = Color.initRgba(200, 16, 46, 255);
// AFC West
pub const NFL_BRONCOS_ORANGE = Color.initRgba(251, 79, 20, 255);
pub const NFL_BRONCOS_NAVY = Color.initRgba(0, 34, 68, 255);
pub const NFL_CHIEFS_RED = Color.initRgba(227, 24, 55, 255);
pub const NFL_CHIEFS_GOLD = Color.initRgba(255, 182, 18, 255);
pub const NFL_RAIDERS_BLACK = Color.initRgba(0, 0, 0, 255);
pub const NFL_RAIDERS_SILVER = Color.initRgba(165, 172, 175, 255);
pub const NFL_CHARGERS_NAVY = Color.initRgba(0, 42, 94, 255);
pub const NFL_CHARGERS_GOLD = Color.initRgba(255, 194, 14, 255);
pub const NFL_CHARGERS_BLUE = Color.initRgba(0, 128, 198, 255);
// NFC East
pub const NFL_COWBOYS_NAVY = Color.initRgba(0, 34, 68, 255);
pub const NFL_COWBOYS_SILVER = Color.initRgba(134, 147, 151, 255);
pub const NFL_COWBOYS_BLUE = Color.initRgba(0, 93, 157, 255);
pub const NFL_GIANTS_BLUE = Color.initRgba(1, 35, 82, 255);
pub const NFL_GIANTS_RED = Color.initRgba(163, 13, 45, 255);
pub const NFL_EAGLES_GREEN = Color.initRgba(0, 76, 84, 255);
pub const NFL_EAGLES_SILVER = Color.initRgba(165, 172, 175, 255);
pub const NFL_EAGLES_BLACK = Color.initRgba(0, 0, 0, 255);
pub const NFL_COMMANDERS_BURGUNDY = Color.initRgba(90, 20, 20, 255);
pub const NFL_COMMANDERS_GOLD = Color.initRgba(255, 182, 18, 255);
// NFC North
pub const NFL_BEARS_NAVY = Color.initRgba(11, 22, 42, 255);
pub const NFL_BEARS_ORANGE = Color.initRgba(200, 56, 3, 255);
pub const NFL_LIONS_BLUE = Color.initRgba(0, 118, 182, 255);
pub const NFL_LIONS_SILVER = Color.initRgba(176, 183, 188, 255);
pub const NFL_PACKERS_GREEN = Color.initRgba(24, 48, 40, 255);
pub const NFL_PACKERS_GOLD = Color.initRgba(255, 184, 28, 255);
pub const NFL_VIKINGS_PURPLE = Color.initRgba(79, 38, 131, 255);
pub const NFL_VIKINGS_GOLD = Color.initRgba(255, 198, 47, 255);
// NFC South
pub const NFL_FALCONS_RED = Color.initRgba(167, 25, 48, 255);
pub const NFL_FALCONS_BLACK = Color.initRgba(0, 0, 0, 255);
pub const NFL_PANTHERS_BLUE = Color.initRgba(0, 133, 202, 255);
pub const NFL_PANTHERS_BLACK = Color.initRgba(16, 24, 32, 255);
pub const NFL_PANTHERS_SILVER = Color.initRgba(191, 192, 191, 255);
pub const NFL_SAINTS_GOLD = Color.initRgba(211, 188, 141, 255);
pub const NFL_SAINTS_BLACK = Color.initRgba(16, 24, 32, 255);
pub const NFL_BUCCANEERS_RED = Color.initRgba(213, 10, 10, 255);
pub const NFL_BUCCANEERS_PEWTER = Color.initRgba(69, 75, 78, 255);
pub const NFL_BUCCANEERS_BLACK = Color.initRgba(52, 48, 43, 255);
// NFC West
pub const NFL_CARDINALS_RED = Color.initRgba(151, 35, 63, 255);
pub const NFL_CARDINALS_BLACK = Color.initRgba(0, 0, 0, 255);
pub const NFL_CARDINALS_WHITE = Color.initRgba(255, 255, 255, 255);
pub const NFL_RAMS_BLUE = Color.initRgba(0, 53, 148, 255);
pub const NFL_RAMS_GOLD = Color.initRgba(255, 209, 0, 255);
pub const NFL_49ERS_RED = Color.initRgba(170, 0, 0, 255);
pub const NFL_49ERS_GOLD = Color.initRgba(173, 153, 93, 255);
pub const NFL_SEAHAWKS_BLUE = Color.initRgba(0, 34, 68, 255);
pub const NFL_SEAHAWKS_GREEN = Color.initRgba(105, 190, 40, 255);
pub const NFL_SEAHAWKS_GRAY = Color.initRgba(165, 172, 175, 255);

// ============================================================================
// GAME UI COLORS
// ============================================================================
// Health Bar
pub const UI_HEALTH_FULL = Color.initRgba(34, 197, 94, 255);
pub const UI_HEALTH_HIGH = Color.initRgba(132, 204, 22, 255);
pub const UI_HEALTH_MID = Color.initRgba(250, 204, 21, 255);
pub const UI_HEALTH_LOW = Color.initRgba(249, 115, 22, 255);
pub const UI_HEALTH_CRITICAL = Color.initRgba(239, 68, 68, 255);
pub const UI_HEALTH_EMPTY = Color.initRgba(127, 29, 29, 255);
// Mana/Energy Bar
pub const UI_MANA_FULL = Color.initRgba(59, 130, 246, 255);
pub const UI_MANA_HIGH = Color.initRgba(99, 102, 241, 255);
pub const UI_MANA_MID = Color.initRgba(139, 92, 246, 255);
pub const UI_MANA_LOW = Color.initRgba(168, 85, 247, 255);
pub const UI_MANA_EMPTY = Color.initRgba(88, 28, 135, 255);
// Stamina/Energy
pub const UI_STAMINA_FULL = Color.initRgba(234, 179, 8, 255);
pub const UI_STAMINA_MID = Color.initRgba(202, 138, 4, 255);
pub const UI_STAMINA_LOW = Color.initRgba(161, 98, 7, 255);
pub const UI_STAMINA_EMPTY = Color.initRgba(113, 63, 18, 255);
// XP Bar
pub const UI_XP_FULL = Color.initRgba(251, 191, 36, 255);
pub const UI_XP_GLOW = Color.initRgba(253, 224, 71, 255);
pub const UI_XP_EMPTY = Color.initRgba(120, 53, 15, 255);
// Rarity Tiers
pub const UI_RARITY_COMMON = Color.initRgba(156, 163, 175, 255);
pub const UI_RARITY_UNCOMMON = Color.initRgba(34, 197, 94, 255);
pub const UI_RARITY_RARE = Color.initRgba(59, 130, 246, 255);
pub const UI_RARITY_EPIC = Color.initRgba(168, 85, 247, 255);
pub const UI_RARITY_LEGENDARY = Color.initRgba(249, 115, 22, 255);
pub const UI_RARITY_MYTHIC = Color.initRgba(239, 68, 68, 255);
pub const UI_RARITY_ARTIFACT = Color.initRgba(236, 72, 153, 255);
// Button States
pub const UI_BUTTON_NORMAL = Color.initRgba(75, 85, 99, 255);
pub const UI_BUTTON_HOVER = Color.initRgba(107, 114, 128, 255);
pub const UI_BUTTON_PRESSED = Color.initRgba(55, 65, 81, 255);
pub const UI_BUTTON_DISABLED = Color.initRgba(31, 41, 55, 255);
pub const UI_BUTTON_TEXT = Color.initRgba(243, 244, 246, 255);
pub const UI_BUTTON_TEXT_DISABLED = Color.initRgba(107, 114, 128, 255);
// Menu/Panel
pub const UI_PANEL_BG = Color.initRgba(17, 24, 39, 230);
pub const UI_PANEL_BORDER = Color.initRgba(55, 65, 81, 255);
pub const UI_PANEL_HIGHLIGHT = Color.initRgba(75, 85, 99, 255);
pub const UI_TOOLTIP_BG = Color.initRgba(0, 0, 0, 220);
pub const UI_TOOLTIP_BORDER = Color.initRgba(75, 85, 99, 255);
// Text Colors
pub const UI_TEXT_PRIMARY = Color.initRgba(255, 255, 255, 255);
pub const UI_TEXT_SECONDARY = Color.initRgba(156, 163, 175, 255);
pub const UI_TEXT_MUTED = Color.initRgba(107, 114, 128, 255);
pub const UI_TEXT_SUCCESS = Color.initRgba(34, 197, 94, 255);
pub const UI_TEXT_WARNING = Color.initRgba(234, 179, 8, 255);
pub const UI_TEXT_ERROR = Color.initRgba(239, 68, 68, 255);
pub const UI_TEXT_INFO = Color.initRgba(59, 130, 246, 255);

// ============================================================================
// BIOME: DESERT
// ============================================================================
pub const DESERT_SAND_LIGHT = Color.initRgba(237, 220, 180, 255);
pub const DESERT_SAND = Color.initRgba(210, 180, 140, 255);
pub const DESERT_SAND_DARK = Color.initRgba(180, 150, 100, 255);
pub const DESERT_DUNE_SHADOW = Color.initRgba(150, 120, 80, 255);
pub const DESERT_TERRACOTTA = Color.initRgba(204, 119, 77, 255);
pub const DESERT_TERRACOTTA_DARK = Color.initRgba(160, 82, 45, 255);
pub const DESERT_CACTUS_GREEN = Color.initRgba(85, 107, 47, 255);
pub const DESERT_CACTUS_DARK = Color.initRgba(60, 80, 35, 255);
pub const DESERT_SUNSET_ORANGE = Color.initRgba(255, 140, 66, 255);
pub const DESERT_SUNSET_RED = Color.initRgba(220, 80, 60, 255);
pub const DESERT_SUNSET_PINK = Color.initRgba(255, 170, 150, 255);
pub const DESERT_SKY_DAY = Color.initRgba(135, 206, 250, 255);
pub const DESERT_SKY_DUSK = Color.initRgba(255, 200, 150, 255);
pub const DESERT_ROCK = Color.initRgba(139, 119, 101, 255);
pub const DESERT_OASIS_BLUE = Color.initRgba(64, 164, 185, 255);

// ============================================================================
// BIOME: TUNDRA / ARCTIC
// ============================================================================
pub const TUNDRA_SNOW_WHITE = Color.initRgba(255, 250, 250, 255);
pub const TUNDRA_SNOW_SHADOW = Color.initRgba(200, 210, 220, 255);
pub const TUNDRA_SNOW_DEEP = Color.initRgba(170, 185, 200, 255);
pub const TUNDRA_ICE_LIGHT = Color.initRgba(200, 230, 255, 255);
pub const TUNDRA_ICE = Color.initRgba(150, 200, 230, 255);
pub const TUNDRA_ICE_DARK = Color.initRgba(100, 150, 200, 255);
pub const TUNDRA_FROST = Color.initRgba(220, 240, 255, 255);
pub const TUNDRA_FROZEN_GROUND = Color.initRgba(80, 90, 100, 255);
pub const TUNDRA_AURORA_GREEN = Color.initRgba(100, 255, 150, 255);
pub const TUNDRA_AURORA_BLUE = Color.initRgba(100, 200, 255, 255);
pub const TUNDRA_AURORA_PURPLE = Color.initRgba(180, 100, 255, 255);
pub const TUNDRA_AURORA_PINK = Color.initRgba(255, 150, 200, 255);
pub const TUNDRA_SKY_DAY = Color.initRgba(180, 210, 230, 255);
pub const TUNDRA_SKY_NIGHT = Color.initRgba(20, 30, 50, 255);
pub const TUNDRA_PINE_SNOW = Color.initRgba(50, 80, 60, 255);

// ============================================================================
// BIOME: SWAMP / MARSH
// ============================================================================
pub const SWAMP_WATER_MURKY = Color.initRgba(60, 80, 50, 200);
pub const SWAMP_WATER_DARK = Color.initRgba(40, 55, 35, 220);
pub const SWAMP_MUD_LIGHT = Color.initRgba(110, 90, 60, 255);
pub const SWAMP_MUD = Color.initRgba(85, 70, 45, 255);
pub const SWAMP_MUD_DARK = Color.initRgba(60, 50, 35, 255);
pub const SWAMP_ALGAE = Color.initRgba(80, 120, 50, 255);
pub const SWAMP_MOSS = Color.initRgba(70, 100, 45, 255);
pub const SWAMP_LILY_PAD = Color.initRgba(60, 130, 60, 255);
pub const SWAMP_FOG = Color.initRgba(150, 160, 140, 180);
pub const SWAMP_DEAD_TREE = Color.initRgba(70, 60, 50, 255);
pub const SWAMP_CYPRESS = Color.initRgba(50, 70, 40, 255);
pub const SWAMP_FIREFLY = Color.initRgba(200, 255, 100, 255);
pub const SWAMP_POISON = Color.initRgba(150, 200, 50, 255);

// ============================================================================
// BIOME: VOLCANO / LAVA
// ============================================================================
pub const VOLCANO_LAVA_HOT = Color.initRgba(255, 200, 50, 255);
pub const VOLCANO_LAVA_BRIGHT = Color.initRgba(255, 140, 0, 255);
pub const VOLCANO_LAVA = Color.initRgba(255, 80, 0, 255);
pub const VOLCANO_LAVA_DARK = Color.initRgba(200, 40, 0, 255);
pub const VOLCANO_LAVA_CRUST = Color.initRgba(80, 20, 10, 255);
pub const VOLCANO_OBSIDIAN = Color.initRgba(20, 15, 25, 255);
pub const VOLCANO_OBSIDIAN_SHINE = Color.initRgba(50, 40, 60, 255);
pub const VOLCANO_ASH = Color.initRgba(80, 80, 85, 255);
pub const VOLCANO_ASH_DARK = Color.initRgba(50, 50, 55, 255);
pub const VOLCANO_SMOKE = Color.initRgba(60, 60, 65, 200);
pub const VOLCANO_EMBER = Color.initRgba(255, 100, 30, 255);
pub const VOLCANO_BASALT = Color.initRgba(40, 40, 45, 255);
pub const VOLCANO_SULFUR = Color.initRgba(200, 180, 50, 255);
pub const VOLCANO_GLOW = Color.initRgba(255, 150, 50, 150);

// ============================================================================
// BIOME: OCEAN / UNDERWATER
// ============================================================================
pub const OCEAN_SURFACE = Color.initRgba(30, 144, 200, 255);
pub const OCEAN_SHALLOW = Color.initRgba(64, 164, 185, 255);
pub const OCEAN_MID = Color.initRgba(30, 100, 150, 255);
pub const OCEAN_DEEP = Color.initRgba(15, 50, 100, 255);
pub const OCEAN_ABYSS = Color.initRgba(5, 20, 50, 255);
pub const OCEAN_SEAFLOOR = Color.initRgba(40, 50, 60, 255);
pub const OCEAN_CORAL_PINK = Color.initRgba(255, 127, 127, 255);
pub const OCEAN_CORAL_ORANGE = Color.initRgba(255, 127, 80, 255);
pub const OCEAN_CORAL_PURPLE = Color.initRgba(180, 100, 180, 255);
pub const OCEAN_SEAWEED = Color.initRgba(50, 120, 70, 255);
pub const OCEAN_BIOLUM_CYAN = Color.initRgba(100, 255, 255, 255);
pub const OCEAN_BIOLUM_BLUE = Color.initRgba(80, 150, 255, 255);
pub const OCEAN_BIOLUM_GREEN = Color.initRgba(100, 255, 180, 255);
pub const OCEAN_JELLYFISH_PINK = Color.initRgba(255, 150, 200, 200);
pub const OCEAN_BUBBLE = Color.initRgba(200, 230, 255, 150);

// ============================================================================
// BIOME: HAUNTED / SPOOKY
// ============================================================================
pub const HAUNTED_FOG = Color.initRgba(150, 160, 170, 150);
pub const HAUNTED_MIST = Color.initRgba(100, 120, 140, 100);
pub const HAUNTED_GHOST_GREEN = Color.initRgba(150, 255, 180, 200);
pub const HAUNTED_GHOST_BLUE = Color.initRgba(150, 200, 255, 200);
pub const HAUNTED_ECTOPLASM = Color.initRgba(100, 255, 150, 180);
pub const HAUNTED_PURPLE = Color.initRgba(80, 40, 100, 255);
pub const HAUNTED_MIDNIGHT = Color.initRgba(20, 15, 40, 255);
pub const HAUNTED_BLOOD_MOON = Color.initRgba(180, 50, 50, 255);
pub const HAUNTED_GRAVE_GRAY = Color.initRgba(80, 85, 90, 255);
pub const HAUNTED_DEAD_GRASS = Color.initRgba(100, 90, 60, 255);
pub const HAUNTED_DEAD_TREE = Color.initRgba(50, 40, 35, 255);
pub const HAUNTED_LANTERN = Color.initRgba(255, 180, 80, 255);
pub const HAUNTED_CANDLE = Color.initRgba(255, 200, 100, 255);
pub const HAUNTED_SOUL = Color.initRgba(200, 220, 255, 150);

// ============================================================================
// MATERIALS: LEATHER
// ============================================================================
pub const MATERIAL_LEATHER_TAN_LIGHT = Color.initRgba(210, 180, 140, 255);
pub const MATERIAL_LEATHER_TAN = Color.initRgba(180, 140, 100, 255);
pub const MATERIAL_LEATHER_TAN_DARK = Color.initRgba(140, 100, 60, 255);
pub const MATERIAL_LEATHER_BROWN_LIGHT = Color.initRgba(160, 110, 70, 255);
pub const MATERIAL_LEATHER_BROWN = Color.initRgba(120, 75, 40, 255);
pub const MATERIAL_LEATHER_BROWN_DARK = Color.initRgba(80, 50, 25, 255);
pub const MATERIAL_LEATHER_BLACK = Color.initRgba(30, 25, 20, 255);
pub const MATERIAL_LEATHER_WORN = Color.initRgba(150, 130, 100, 255);
pub const MATERIAL_LEATHER_AGED = Color.initRgba(130, 110, 80, 255);
pub const MATERIAL_LEATHER_RED = Color.initRgba(140, 50, 40, 255);
pub const MATERIAL_LEATHER_BURGUNDY = Color.initRgba(100, 40, 50, 255);
pub const MATERIAL_LEATHER_GREEN = Color.initRgba(60, 80, 50, 255);
pub const MATERIAL_LEATHER_BLUE = Color.initRgba(50, 60, 90, 255);

// ============================================================================
// MATERIALS: CLOTH / FABRIC
// ============================================================================
pub const CLOTH_LINEN_WHITE = Color.initRgba(250, 240, 230, 255);
pub const CLOTH_LINEN_NATURAL = Color.initRgba(230, 220, 200, 255);
pub const CLOTH_LINEN_DARK = Color.initRgba(200, 185, 160, 255);
pub const CLOTH_SILK_WHITE = Color.initRgba(255, 252, 250, 255);
pub const CLOTH_SILK_CREAM = Color.initRgba(255, 245, 230, 255);
pub const CLOTH_SILK_GOLD = Color.initRgba(255, 215, 150, 255);
pub const CLOTH_SILK_RED = Color.initRgba(200, 50, 50, 255);
pub const CLOTH_SILK_BLUE = Color.initRgba(70, 100, 180, 255);
pub const CLOTH_DENIM_LIGHT = Color.initRgba(130, 150, 180, 255);
pub const CLOTH_DENIM = Color.initRgba(80, 100, 140, 255);
pub const CLOTH_DENIM_DARK = Color.initRgba(50, 65, 100, 255);
pub const CLOTH_VELVET_RED = Color.initRgba(150, 30, 50, 255);
pub const CLOTH_VELVET_PURPLE = Color.initRgba(80, 40, 100, 255);
pub const CLOTH_VELVET_BLUE = Color.initRgba(30, 50, 100, 255);
pub const CLOTH_VELVET_GREEN = Color.initRgba(30, 80, 50, 255);
pub const CLOTH_BURLAP = Color.initRgba(180, 160, 120, 255);
pub const CLOTH_CANVAS = Color.initRgba(220, 210, 190, 255);

// ============================================================================
// MATERIALS: STONE TYPES
// ============================================================================
pub const STONE_GRANITE_LIGHT = Color.initRgba(180, 170, 165, 255);
pub const STONE_GRANITE = Color.initRgba(140, 130, 125, 255);
pub const STONE_GRANITE_DARK = Color.initRgba(100, 90, 85, 255);
pub const STONE_MARBLE_WHITE = Color.initRgba(245, 245, 245, 255);
pub const STONE_MARBLE_GRAY = Color.initRgba(200, 200, 200, 255);
pub const STONE_MARBLE_VEIN = Color.initRgba(170, 170, 175, 255);
pub const STONE_SLATE_LIGHT = Color.initRgba(120, 130, 140, 255);
pub const STONE_SLATE = Color.initRgba(80, 90, 100, 255);
pub const STONE_SLATE_DARK = Color.initRgba(50, 60, 70, 255);
pub const STONE_SANDSTONE_LIGHT = Color.initRgba(230, 210, 180, 255);
pub const STONE_SANDSTONE = Color.initRgba(200, 175, 140, 255);
pub const STONE_SANDSTONE_DARK = Color.initRgba(170, 140, 100, 255);
pub const STONE_LIMESTONE = Color.initRgba(220, 215, 200, 255);
pub const STONE_COBBLE_LIGHT = Color.initRgba(160, 160, 155, 255);
pub const STONE_COBBLE = Color.initRgba(120, 120, 115, 255);
pub const STONE_COBBLE_DARK = Color.initRgba(80, 80, 75, 255);
pub const STONE_MOSSY = Color.initRgba(90, 110, 80, 255);

// ============================================================================
// MATERIALS: WOOD GRAINS
// ============================================================================
pub const WOOD_OAK_LIGHT = Color.initRgba(200, 170, 130, 255);
pub const WOOD_OAK = Color.initRgba(170, 130, 90, 255);
pub const WOOD_OAK_DARK = Color.initRgba(130, 95, 60, 255);
pub const WOOD_MAHOGANY_LIGHT = Color.initRgba(160, 80, 60, 255);
pub const WOOD_MAHOGANY = Color.initRgba(120, 50, 40, 255);
pub const WOOD_MAHOGANY_DARK = Color.initRgba(80, 30, 25, 255);
pub const WOOD_BIRCH_LIGHT = Color.initRgba(240, 230, 210, 255);
pub const WOOD_BIRCH = Color.initRgba(220, 205, 180, 255);
pub const WOOD_BIRCH_DARK = Color.initRgba(190, 175, 150, 255);
pub const WOOD_EBONY = Color.initRgba(40, 30, 25, 255);
pub const WOOD_EBONY_GRAIN = Color.initRgba(55, 45, 40, 255);
pub const WOOD_CHERRY_LIGHT = Color.initRgba(200, 130, 100, 255);
pub const WOOD_CHERRY = Color.initRgba(170, 90, 70, 255);
pub const WOOD_CHERRY_DARK = Color.initRgba(130, 60, 50, 255);
pub const WOOD_PINE_LIGHT = Color.initRgba(230, 200, 150, 255);
pub const WOOD_PINE = Color.initRgba(200, 165, 115, 255);
pub const WOOD_PINE_DARK = Color.initRgba(160, 125, 80, 255);
pub const WOOD_WALNUT = Color.initRgba(90, 60, 40, 255);
pub const WOOD_DRIFTWOOD = Color.initRgba(160, 150, 140, 255);
pub const WOOD_WEATHERED = Color.initRgba(140, 130, 115, 255);

// ============================================================================
// SKIN TONES: HUMAN
// ============================================================================
pub const SKIN_PORCELAIN = Color.initRgba(255, 240, 230, 255);
pub const SKIN_FAIR = Color.initRgba(255, 224, 205, 255);
pub const SKIN_LIGHT = Color.initRgba(240, 200, 175, 255);
pub const SKIN_LIGHT_TAN = Color.initRgba(225, 180, 150, 255);
pub const SKIN_TAN = Color.initRgba(200, 155, 120, 255);
pub const SKIN_OLIVE = Color.initRgba(185, 150, 110, 255);
pub const SKIN_MEDIUM = Color.initRgba(175, 130, 95, 255);
pub const SKIN_MEDIUM_DARK = Color.initRgba(150, 110, 75, 255);
pub const SKIN_DARK = Color.initRgba(120, 85, 55, 255);
pub const SKIN_DEEP_BROWN = Color.initRgba(90, 60, 40, 255);
pub const SKIN_EBONY = Color.initRgba(60, 40, 30, 255);
// Blush/Undertones
pub const SKIN_BLUSH_PINK = Color.initRgba(255, 180, 180, 255);
pub const SKIN_BLUSH_PEACH = Color.initRgba(255, 190, 160, 255);
pub const SKIN_SHADOW = Color.initRgba(180, 140, 120, 255);
pub const SKIN_HIGHLIGHT = Color.initRgba(255, 235, 220, 255);

// ============================================================================
// SKIN TONES: FANTASY RACES
// ============================================================================
pub const SKIN_ORC_LIGHT = Color.initRgba(120, 150, 90, 255);
pub const SKIN_ORC = Color.initRgba(90, 120, 60, 255);
pub const SKIN_ORC_DARK = Color.initRgba(60, 90, 40, 255);
pub const SKIN_GOBLIN = Color.initRgba(100, 140, 80, 255);
pub const SKIN_TROLL = Color.initRgba(80, 100, 70, 255);
pub const SKIN_ELF_PALE = Color.initRgba(250, 240, 235, 255);
pub const SKIN_ELF_MOON = Color.initRgba(230, 230, 250, 255);
pub const SKIN_ELF_WOOD = Color.initRgba(200, 170, 130, 255);
pub const SKIN_ELF_DARK = Color.initRgba(80, 60, 100, 255);
pub const SKIN_DWARF_RUDDY = Color.initRgba(200, 150, 130, 255);
pub const SKIN_DWARF_TAN = Color.initRgba(180, 140, 110, 255);
pub const SKIN_UNDEAD_GRAY = Color.initRgba(150, 160, 155, 255);
pub const SKIN_UNDEAD_GREEN = Color.initRgba(130, 150, 120, 255);
pub const SKIN_UNDEAD_PALE = Color.initRgba(200, 200, 195, 255);
pub const SKIN_DEMON_RED = Color.initRgba(180, 50, 50, 255);
pub const SKIN_DEMON_DARK = Color.initRgba(80, 30, 30, 255);
pub const SKIN_TIEFLING_PURPLE = Color.initRgba(140, 80, 160, 255);
pub const SKIN_TIEFLING_BLUE = Color.initRgba(80, 100, 180, 255);
pub const SKIN_DRAGONBORN_RED = Color.initRgba(160, 60, 50, 255);
pub const SKIN_DRAGONBORN_BLUE = Color.initRgba(60, 90, 140, 255);
pub const SKIN_DRAGONBORN_GREEN = Color.initRgba(60, 120, 70, 255);
pub const SKIN_DRAGONBORN_GOLD = Color.initRgba(200, 170, 80, 255);

// ============================================================================
// TIME OF DAY: DAWN
// ============================================================================
pub const DAWN_SKY_HIGH = Color.initRgba(135, 180, 220, 255);
pub const DAWN_SKY_MID = Color.initRgba(255, 200, 170, 255);
pub const DAWN_SKY_HORIZON = Color.initRgba(255, 170, 130, 255);
pub const DAWN_SUN = Color.initRgba(255, 220, 150, 255);
pub const DAWN_CLOUD_LIGHT = Color.initRgba(255, 220, 200, 255);
pub const DAWN_CLOUD_PINK = Color.initRgba(255, 180, 180, 255);
pub const DAWN_CLOUD_PURPLE = Color.initRgba(200, 160, 200, 255);
pub const DAWN_MIST = Color.initRgba(220, 210, 200, 180);
pub const DAWN_SHADOW = Color.initRgba(100, 90, 120, 255);
pub const DAWN_GOLD = Color.initRgba(255, 200, 100, 255);
pub const DAWN_PEACH = Color.initRgba(255, 200, 170, 255);
pub const DAWN_ROSE = Color.initRgba(255, 170, 170, 255);

// ============================================================================
// TIME OF DAY: DUSK / SUNSET
// ============================================================================
pub const DUSK_SKY_HIGH = Color.initRgba(60, 80, 140, 255);
pub const DUSK_SKY_MID = Color.initRgba(140, 100, 160, 255);
pub const DUSK_SKY_HORIZON = Color.initRgba(255, 120, 80, 255);
pub const DUSK_SUN = Color.initRgba(255, 100, 50, 255);
pub const DUSK_ORANGE_DEEP = Color.initRgba(255, 80, 30, 255);
pub const DUSK_PURPLE_LIGHT = Color.initRgba(120, 80, 160, 255);
pub const DUSK_PURPLE_DEEP = Color.initRgba(80, 50, 120, 255);
pub const DUSK_PINK = Color.initRgba(255, 140, 180, 255);
pub const DUSK_CLOUD_ORANGE = Color.initRgba(255, 150, 100, 255);
pub const DUSK_CLOUD_PURPLE = Color.initRgba(180, 130, 180, 255);
pub const DUSK_SHADOW = Color.initRgba(50, 40, 80, 255);
pub const DUSK_SILHOUETTE = Color.initRgba(30, 25, 50, 255);

// ============================================================================
// TIME OF DAY: OVERCAST / STORMY
// ============================================================================
pub const OVERCAST_SKY = Color.initRgba(160, 165, 170, 255);
pub const OVERCAST_SKY_DARK = Color.initRgba(130, 135, 140, 255);
pub const OVERCAST_CLOUD = Color.initRgba(180, 185, 190, 255);
pub const OVERCAST_CLOUD_DARK = Color.initRgba(100, 105, 115, 255);
pub const STORMY_SKY = Color.initRgba(70, 75, 90, 255);
pub const STORMY_SKY_DARK = Color.initRgba(40, 45, 60, 255);
pub const STORMY_CLOUD = Color.initRgba(60, 65, 80, 255);
pub const STORMY_CLOUD_DARK = Color.initRgba(35, 40, 55, 255);
pub const STORMY_LIGHTNING = Color.initRgba(255, 255, 230, 255);
pub const STORMY_RAIN = Color.initRgba(150, 170, 200, 200);
pub const OVERCAST_SHADOW = Color.initRgba(80, 85, 95, 255);
pub const OVERCAST_MUTED = Color.initRgba(140, 145, 150, 255);

// ============================================================================
// FOOD: FRUITS
// ============================================================================
pub const FOOD_APPLE_RED = Color.initRgba(200, 50, 50, 255);
pub const FOOD_APPLE_GREEN = Color.initRgba(120, 180, 80, 255);
pub const FOOD_APPLE_YELLOW = Color.initRgba(230, 210, 80, 255);
pub const FOOD_ORANGE = Color.initRgba(255, 140, 30, 255);
pub const FOOD_ORANGE_PEEL = Color.initRgba(255, 160, 50, 255);
pub const FOOD_LEMON = Color.initRgba(255, 240, 80, 255);
pub const FOOD_LIME = Color.initRgba(180, 220, 80, 255);
pub const FOOD_BANANA = Color.initRgba(255, 230, 100, 255);
pub const FOOD_GRAPE_PURPLE = Color.initRgba(120, 60, 130, 255);
pub const FOOD_GRAPE_GREEN = Color.initRgba(180, 220, 120, 255);
pub const FOOD_STRAWBERRY = Color.initRgba(220, 60, 60, 255);
pub const FOOD_STRAWBERRY_SEED = Color.initRgba(255, 230, 100, 255);
pub const FOOD_BLUEBERRY = Color.initRgba(70, 80, 140, 255);
pub const FOOD_RASPBERRY = Color.initRgba(200, 50, 80, 255);
pub const FOOD_WATERMELON_RED = Color.initRgba(255, 100, 100, 255);
pub const FOOD_WATERMELON_GREEN = Color.initRgba(80, 140, 80, 255);
pub const FOOD_WATERMELON_RIND = Color.initRgba(180, 220, 180, 255);
pub const FOOD_CHERRY = Color.initRgba(180, 30, 50, 255);
pub const FOOD_PEACH = Color.initRgba(255, 200, 150, 255);
pub const FOOD_PLUM = Color.initRgba(100, 50, 100, 255);

// ============================================================================
// FOOD: VEGETABLES
// ============================================================================
pub const FOOD_CARROT = Color.initRgba(255, 140, 50, 255);
pub const FOOD_CARROT_TOP = Color.initRgba(80, 140, 60, 255);
pub const FOOD_TOMATO = Color.initRgba(220, 60, 50, 255);
pub const FOOD_TOMATO_STEM = Color.initRgba(80, 130, 50, 255);
pub const FOOD_LETTUCE_LIGHT = Color.initRgba(180, 220, 140, 255);
pub const FOOD_LETTUCE = Color.initRgba(120, 180, 90, 255);
pub const FOOD_LETTUCE_DARK = Color.initRgba(80, 140, 60, 255);
pub const FOOD_BROCCOLI = Color.initRgba(60, 120, 50, 255);
pub const FOOD_CORN = Color.initRgba(255, 220, 100, 255);
pub const FOOD_CORN_HUSK = Color.initRgba(180, 200, 140, 255);
pub const FOOD_POTATO = Color.initRgba(180, 150, 100, 255);
pub const FOOD_POTATO_SKIN = Color.initRgba(150, 120, 80, 255);
pub const FOOD_ONION = Color.initRgba(220, 200, 160, 255);
pub const FOOD_ONION_RED = Color.initRgba(160, 60, 100, 255);
pub const FOOD_PEPPER_RED = Color.initRgba(200, 50, 40, 255);
pub const FOOD_PEPPER_YELLOW = Color.initRgba(255, 220, 60, 255);
pub const FOOD_PEPPER_GREEN = Color.initRgba(80, 150, 60, 255);
pub const FOOD_EGGPLANT = Color.initRgba(80, 50, 100, 255);
pub const FOOD_PUMPKIN = Color.initRgba(240, 140, 50, 255);
pub const FOOD_MUSHROOM_CAP = Color.initRgba(180, 140, 100, 255);
pub const FOOD_MUSHROOM_STEM = Color.initRgba(240, 230, 210, 255);

// ============================================================================
// FOOD: MEATS AND PROTEINS
// ============================================================================
pub const FOOD_BEEF_RAW = Color.initRgba(180, 60, 70, 255);
pub const FOOD_BEEF_COOKED = Color.initRgba(120, 70, 50, 255);
pub const FOOD_BEEF_WELL = Color.initRgba(90, 55, 40, 255);
pub const FOOD_CHICKEN_RAW = Color.initRgba(255, 200, 180, 255);
pub const FOOD_CHICKEN_COOKED = Color.initRgba(220, 170, 120, 255);
pub const FOOD_PORK = Color.initRgba(255, 180, 170, 255);
pub const FOOD_BACON = Color.initRgba(180, 80, 80, 255);
pub const FOOD_FISH_RAW = Color.initRgba(255, 180, 170, 255);
pub const FOOD_FISH_COOKED = Color.initRgba(220, 200, 180, 255);
pub const FOOD_SALMON = Color.initRgba(255, 140, 120, 255);
pub const FOOD_EGG_SHELL = Color.initRgba(245, 235, 220, 255);
pub const FOOD_EGG_WHITE = Color.initRgba(255, 255, 250, 255);
pub const FOOD_EGG_YOLK = Color.initRgba(255, 200, 60, 255);
pub const FOOD_SHRIMP = Color.initRgba(255, 160, 140, 255);

// ============================================================================
// FOOD: BREADS AND BAKED
// ============================================================================
pub const FOOD_BREAD_CRUST = Color.initRgba(180, 130, 80, 255);
pub const FOOD_BREAD_INSIDE = Color.initRgba(240, 220, 180, 255);
pub const FOOD_BREAD_DARK = Color.initRgba(140, 100, 60, 255);
pub const FOOD_TOAST = Color.initRgba(200, 150, 90, 255);
pub const FOOD_TOAST_BURNT = Color.initRgba(80, 60, 40, 255);
pub const FOOD_CROISSANT = Color.initRgba(220, 180, 120, 255);
pub const FOOD_PIE_CRUST = Color.initRgba(210, 170, 110, 255);
pub const FOOD_CHOCOLATE = Color.initRgba(70, 40, 30, 255);
pub const FOOD_CHOCOLATE_MILK = Color.initRgba(120, 80, 60, 255);
pub const FOOD_CHOCOLATE_WHITE = Color.initRgba(250, 240, 220, 255);
pub const FOOD_CAKE_VANILLA = Color.initRgba(255, 245, 220, 255);
pub const FOOD_CAKE_CHOCOLATE = Color.initRgba(80, 50, 40, 255);
pub const FOOD_FROSTING_WHITE = Color.initRgba(255, 255, 250, 255);
pub const FOOD_FROSTING_PINK = Color.initRgba(255, 200, 210, 255);
pub const FOOD_COOKIE = Color.initRgba(200, 160, 100, 255);

// ============================================================================
// FOOD: DRINKS
// ============================================================================
pub const FOOD_WATER = Color.initRgba(200, 230, 255, 200);
pub const FOOD_MILK = Color.initRgba(255, 252, 245, 255);
pub const FOOD_JUICE_ORANGE = Color.initRgba(255, 180, 50, 255);
pub const FOOD_JUICE_APPLE = Color.initRgba(220, 200, 100, 255);
pub const FOOD_JUICE_GRAPE = Color.initRgba(100, 50, 120, 255);
pub const FOOD_COFFEE = Color.initRgba(80, 50, 30, 255);
pub const FOOD_COFFEE_CREAM = Color.initRgba(160, 120, 80, 255);
pub const FOOD_TEA = Color.initRgba(180, 130, 70, 200);
pub const FOOD_TEA_GREEN = Color.initRgba(150, 180, 100, 200);
pub const FOOD_WINE_RED = Color.initRgba(120, 30, 50, 255);
pub const FOOD_WINE_WHITE = Color.initRgba(240, 230, 180, 200);
pub const FOOD_BEER = Color.initRgba(220, 180, 80, 200);
pub const FOOD_BEER_DARK = Color.initRgba(80, 50, 30, 255);
pub const FOOD_SODA_COLA = Color.initRgba(60, 30, 20, 255);
pub const FOOD_SODA_LEMON = Color.initRgba(255, 255, 200, 200);
