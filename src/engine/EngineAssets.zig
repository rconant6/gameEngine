const Engine = @import("../engine.zig").Engine;
const assets = @import("assets");
const Font = assets.Font;
const debug = @import("debug");
const log = debug.log;

pub fn getFont(self: *Engine, name: []const u8) !*const Font {
    return self.assets.getFontByName(name) catch |err| {
        log.err(.assets, "Unable to get Font[{s}] {any}", .{ name, err });
        return err;
    };
}
