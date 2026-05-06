const std = @import("std");
const parent = @import("../build.zig");

const RendererBackend = parent.RendererBackend;

/// Link Linux-specific libraries onto a module.
pub fn configureModule(
    module: *std.Build.Module,
    renderer: RendererBackend,
) void {
    module.link_libc = true;
    // for ([_][]const u8{ "xkbcommon" }) |lib| module.linkSystemLibrary(lib, .{});
    switch (renderer) {
        .vulkan => module.linkSystemLibrary("vulkan", .{}),
        .opengl => @panic("openGL is not implemented"),
        .metal => @panic("Metal is not available on Linux"),
        .cpu => {},
    }
}
