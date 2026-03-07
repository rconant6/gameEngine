const std = @import("std");
const parent = @import("../build.zig");

const RendererBackend = parent.RendererBackend;

/// Link Windows-specific libraries onto a module.
pub fn configureModule(
    module: *std.Build.Module,
    renderer: RendererBackend,
) void {
    for ([_][]const u8{ "user32", "gdi32", "shell32", "kernel32" }) |lib| module.linkSystemLibrary(lib, .{});
    switch (renderer) {
        .vulkan => module.linkSystemLibrary("vulkan-1", .{}),
        .opengl => module.linkSystemLibrary("opengl32", .{}),
        .metal => @panic("Metal is not available on Windows"),
        .cpu => {},
    }
}
