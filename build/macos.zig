const std = @import("std");
const parent = @import("../build.zig");

const RendererBackend = parent.RendererBackend;

/// Link macOS frameworks and Swift runtime libraries onto a module.
pub fn configureModule(
    b: *std.Build,
    module: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    renderer: RendererBackend,
) void {
    const frameworks = [_][]const u8{ "Foundation", "AppKit", "QuartzCore", "CoreGraphics" };
    for (frameworks) |fw| module.linkFramework(fw, .{});

    switch (renderer) {
        .metal => {
            module.linkFramework("Metal", .{});
            module.linkFramework("MetalKit", .{});
        },
        .opengl => module.linkFramework("OpenGL", .{}),
        .vulkan => {
            module.linkSystemLibrary("vulkan", .{});
            module.linkSystemLibrary("MoltenVK", .{});
        },
        .cpu => {
            module.linkFramework("Metal", .{ .weak = true });
            module.linkFramework("MetalKit", .{ .weak = true });
        },
    }

    // Swift library paths — discovered dynamically so they survive Xcode/SDK updates
    const sdk_path = std.zig.system.darwin.getSdk(b.allocator, &target.result) orelse
        @panic("Could not find macOS SDK. Is Xcode or Command Line Tools installed?");
    const sdk_swift = std.fs.path.join(b.allocator, &.{ sdk_path, "usr/lib/swift" }) catch @panic("OOM");
    module.addLibraryPath(.{ .cwd_relative = sdk_swift });
    module.addLibraryPath(.{ .cwd_relative = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx" });

    // Swift runtime libraries (required by Zig's linker — it doesn't support LC_LINKER_OPTION auto-linking)
    const swift_libs = [_][]const u8{
        "swiftObjectiveC",      "swiftCore",                     "swiftAppKit",
        "swiftCoreFoundation",  "swiftCompatibilityConcurrency", "swiftCompatibility50",
        "swiftCompatibility51", "swiftCompatibility56",          "swiftCompatibilityDynamicReplacements",
        "swift_Concurrency",    "swiftUniformTypeIdentifiers",   "swift_StringProcessing",
        "swiftDispatch",        "swiftCoreGraphics",             "swiftIOKit",
        "swiftXPC",             "swiftDarwin",                   "swiftCoreImage",
        "swiftQuartzCore",      "swiftOSLog",                    "swiftos",
        "swiftsimd",
    };
    for (swift_libs) |lib| module.linkSystemLibrary(lib, .{});

    // Metal Swift libraries (weak when not using Metal renderer)
    const metal_swift = [_][]const u8{ "swiftMetal", "swiftMetalKit", "swiftModelIO" };
    const link_opt: std.Build.Module.LinkSystemLibraryOptions = if (renderer == .metal) .{} else .{ .weak = true };
    for (metal_swift) |lib| module.linkSystemLibrary(lib, link_opt);
}

/// Result of building the Swift platform library.
pub const SwiftBuildResult = struct {
    swift_step: *std.Build.Step,
    lib_path: []const u8,
    metallib_install: ?*std.Build.Step,
};

/// Build the Swift platform library once. Returns the step and path for linking.
pub fn buildSwiftLibrary(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    renderer: RendererBackend,
) ?SwiftBuildResult {
    if (target.result.os.tag != .macos) return null;

    const arch = switch (target.result.cpu.arch) {
        .aarch64 => "arm64",
        .x86_64 => "x86_64",
        else => @panic("Unsupported architecture for macOS"),
    };

    const config = if (optimize == .Debug) "debug" else "release";
    const package_path = b.path("src/platform/macos").getPath(b);
    const swift_scratch_rel = b.fmt("swift-build/{s}", .{config});
    const swift_scratch = b.cache_root.join(b.allocator, &.{swift_scratch_rel}) catch @panic("OOM");
    const swift_build_dir = b.path("src/platform/macos/.build").getPath(b);

    const swift_build = b.addSystemCommand(&.{
        "swift",          "build",
        "--package-path", package_path,
        "--scratch-path", swift_scratch,
        "-c",             config,
        "--arch",         arch,
        "-Xswiftc",       if (renderer == .metal) "-DUSE_METAL" else "-DUSE_CPU",
    });

    // Clean the .build dir swift leaves behind
    const swift_clean = b.addSystemCommand(&.{ "rm", "-rf", swift_build_dir });
    swift_build.step.dependOn(&swift_clean.step);

    const lib_path = b.fmt("{s}/arm64-apple-macosx/{s}/libMacPlatform.a", .{ swift_scratch, config });

    const install_lib = b.addInstallFile(.{ .cwd_relative = lib_path }, "lib/libMacPlatform.a");
    install_lib.step.dependOn(&swift_build.step);

    // Metal shaders
    var metallib_install: ?*std.Build.Step = null;
    if (renderer == .metal) {
        const shaders_metal = b.path("src/platform/macos/swift/shaders.metal").getPath(b);
        const shaders_air = b.cache_root.join(b.allocator, &.{"shaders.air"}) catch @panic("OOM");
        const metallib_path = b.cache_root.join(b.allocator, &.{"default.metallib"}) catch @panic("OOM");

        const metal_compile = b.addSystemCommand(&.{
            "xcrun", "-sdk", "macosx", "metal", "-c", shaders_metal, "-o", shaders_air,
        });
        metal_compile.step.dependOn(&swift_build.step);

        const metal_lib = b.addSystemCommand(&.{
            "xcrun", "-sdk", "macosx", "metallib", shaders_air, "-o", metallib_path,
        });
        metal_lib.step.dependOn(&metal_compile.step);

        const install_metallib = b.addInstallFile(.{ .cwd_relative = metallib_path }, "bin/default.metallib");
        install_metallib.step.dependOn(&metal_lib.step);
        metallib_install = &install_metallib.step;
    }

    return .{
        .swift_step = &swift_build.step,
        .lib_path = lib_path,
        .metallib_install = metallib_install,
    };
}

/// Link an executable against the shared Swift library (built once).
pub fn linkSwiftLibrary(
    exe: *std.Build.Step.Compile,
    swift_lib: ?SwiftBuildResult,
    target: std.Build.ResolvedTarget,
) void {
    if (target.result.os.tag != .macos) return;
    const sl = swift_lib orelse return;

    exe.linkSystemLibrary("c++");
    exe.addObjectFile(.{ .cwd_relative = sl.lib_path });
    exe.step.dependOn(sl.swift_step);

    if (sl.metallib_install) |metallib_step| {
        exe.step.dependOn(metallib_step);
    }
}
