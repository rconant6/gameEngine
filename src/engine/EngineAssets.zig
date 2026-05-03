const Engine = @import("../Engine.zig").Engine;
const assets = @import("assets");
const Font = assets.Font;
const debug = @import("debug");
const log = debug.log;

pub fn getFont(self: *Engine, name: []const u8) !*const Font {
    return self.assets.getFont(name) orelse {
        log.err(.assets, "Font not found: {s}", .{name});
        return error.FontNotFound;
    };
}
