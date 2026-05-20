const std = @import("std");
const parent = @import("../build.zig");

const RendererBackend = parent.RendererBackend;

/// Link Linux-specific libraries onto a module.
pub fn configureModule(
    b: *std.Build,
    module: *std.Build.Module,
    renderer: RendererBackend,
) void {
    module.link_libc = true;
    module.addIncludePath(b.path("src/platform/linux"));
    switch (renderer) {
        .vulkan => {
            module.linkSystemLibrary("vulkan", .{});
            module.linkSystemLibrary("wayland-client", .{});
            module.addCSourceFile(.{
                .file = b.path("src/platform/linux/xdg-shell-private.c"),
                .flags = &.{},
            });
        },
        .opengl => @panic("OpenGL is not currently supported on Linux"),
        .metal => @panic("Metal is not available on Linux"),
        .cpu => {},
    }
}
