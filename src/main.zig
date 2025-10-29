const std = @import("std");
const platform = @import("platform");

pub fn main() !void {
    try platform.init();
    defer platform.deinit();

    const window = try platform.createWindow(.{
        .title = "Game Engine",
        .width = 1280,
        .height = 720,
    });
    defer window.destroy();

    while (!window.shouldClose()) {
        platform.pollEvents();

        // Game shit

        window.swapBuffers();
    }
}
