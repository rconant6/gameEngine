const std = @import("std");
const parent = @import("../build.zig");

const RendererBackend = parent.RendererBackend;

/// Link Linux-specific libraries onto a module.
pub fn configureModule(
    module: *std.Build.Module,
    renderer: RendererBackend,
) void {
    module.link_libc = true;
    for ([_][]const u8{ "wayland-client", "xkbcommon" }) |lib| module.linkSystemLibrary(lib, .{});
    switch (renderer) {
        .vulkan => module.linkSystemLibrary("vulkan", .{}),
        .opengl => module.linkSystemLibrary("GL", .{}),
        .metal => @panic("Metal is not available on Linux"),
        .cpu => {},
    }
}
