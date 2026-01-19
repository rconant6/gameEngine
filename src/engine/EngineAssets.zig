const Engine = @import("../engine.zig").Engine;
const assets = @import("assets");
const Font = assets.Font;

pub fn getFont(self: *Engine, name: []const u8) !*const Font {
    return self.assets.getFontByName(name) catch |err| {
        self.logError(.assets, "Unable to get Font[{s}] {any}", .{ name, err });
        return err;
    };
}
