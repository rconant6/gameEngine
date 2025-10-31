const std = @import("std");
const builtin = @import("builtin");

const RendererBackend = enum { metal, vulkan, opengl, cpu };

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build options
    const renderer_backend = b.option(
        RendererBackend,
        "renderer",
        "Graphics backend (default: platform optimal)",
    );
    const enable_validation = b.option(
        bool,
        "validation",
        "Enable validation layers (default: debug builds)",
    ) orelse (optimize == .Debug);

    // Determine default renderer if not specified
    const selected_renderer = renderer_backend orelse defaultRendererForTarget(target.result.os.tag);

    // Create modules
    const core_module = b.addModule("core", .{
        .root_source_file = b.path("src/core/types.zig"),
    });

    const renderer_module = b.addModule("renderer", .{
        .root_source_file = b.path("src/renderer/renderer.zig"),
    });
    renderer_module.addImport("core", core_module);

    // Add renderer backend options
    const renderer_options = b.addOptions();
    renderer_options.addOption(RendererBackend, "backend", selected_renderer);
    renderer_options.addOption(bool, "enable_validation", enable_validation);
    renderer_module.addImport("build_options", renderer_options.createModule());

    // Platform module
    const platform_module = b.addModule("platform", .{
        .root_source_file = b.path("src/platform/platform.zig"),
    });
    platform_module.addIncludePath(b.path("src/platform/macos/swift/include"));

    // API module
    const api_module = b.addModule("api", .{
        .root_source_file = b.path("src/api/engine.zig"),
    });
    api_module.addImport("core", core_module);
    api_module.addImport("platform", platform_module);
    api_module.addImport("renderer", renderer_module);

    // Main module for executable
    const main_module = b.addModule("main", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    main_module.addImport("core", core_module);
    main_module.addImport("platform", platform_module);
    main_module.addImport("renderer", renderer_module);
    main_module.addImport("api", api_module);

    // Main executable
    const exe = b.addExecutable(.{
        .name = "game-engine",
        .root_module = main_module,
    });

    // Add imports to exe's root_module
    exe.root_module.addImport("core", core_module);
    exe.root_module.addImport("platform", platform_module);
    exe.root_module.addImport("renderer", renderer_module);
    exe.root_module.addImport("api", api_module);

    // Configure platform-specific stuff on root_module
    configurePlatform(b, exe, main_module, target, optimize, selected_renderer);

    if (target.result.os.tag == .macos) {
        const swift_build_dir = switch (optimize) {
            .Debug => "src/platform/macos/.build/debug/",
            .ReleaseSafe, .ReleaseFast, .ReleaseSmall => "src/platform/macos/.build/release/",
        };

        std.debug.print("{s}\n", .{swift_build_dir});
        const lib_path = b.pathJoin(&.{ swift_build_dir, "libMacPlatform.a" });
        std.debug.print("{s}\n", .{lib_path});
        exe.root_module.addLibraryPath(.{ .cwd_relative = swift_build_dir });
        exe.root_module.addObjectFile(.{ .cwd_relative = lib_path });
        // Swift runtime dependencies
        exe.linkSystemLibrary("c++");
        exe.linkFramework("Cocoa");
        exe.linkFramework("Foundation");
        exe.linkFramework("AppKit");

        const sys_path = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.sdk/usr/lib/swift/";
        const other_sys_path = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx";
        exe.root_module.addLibraryPath(.{ .cwd_relative = sys_path });
        exe.root_module.addLibraryPath(.{ .cwd_relative = other_sys_path });

        exe.root_module.linkSystemLibrary("swiftObjectiveC", .{});
        exe.root_module.linkSystemLibrary("swiftCore", .{});
        exe.root_module.linkSystemLibrary("swiftAppKit", .{});
        exe.root_module.linkSystemLibrary("swiftCoreFoundation", .{});
        exe.root_module.linkSystemLibrary("swiftCompatibilityConcurrency", .{});
        exe.root_module.linkSystemLibrary("swiftCompatibility50", .{});
        exe.root_module.linkSystemLibrary("swiftCompatibility51", .{});
        exe.root_module.linkSystemLibrary("swiftCompatibility56", .{});
        exe.root_module.linkSystemLibrary("swiftCompatibilityDynamicReplacements", .{});
        exe.root_module.linkSystemLibrary("swift_Concurrency", .{});
        exe.root_module.linkSystemLibrary("swiftUniformTypeIdentifiers", .{});
        exe.root_module.linkSystemLibrary("swift_StringProcessing", .{});
        exe.root_module.linkSystemLibrary("swiftDispatch", .{});
        exe.root_module.linkSystemLibrary("swiftObjectiveC", .{});
        exe.root_module.linkSystemLibrary("swiftCoreGraphics", .{});
        exe.root_module.linkSystemLibrary("swiftMetal", .{});
        exe.root_module.linkSystemLibrary("swiftIOKit", .{});
        exe.root_module.linkSystemLibrary("swiftXPC", .{});
        exe.root_module.linkSystemLibrary("swiftDarwin", .{});
        exe.root_module.linkSystemLibrary("swiftCoreImage", .{});
        exe.root_module.linkSystemLibrary("swiftQuartzCore", .{});
        exe.root_module.linkSystemLibrary("swiftOSLog", .{});
        exe.root_module.linkSystemLibrary("swiftos", .{});
        exe.root_module.linkSystemLibrary("swiftsimd", .{});
    }
    b.installArtifact(exe);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the engine");
    run_step.dependOn(&run_cmd.step);
}

fn defaultRendererForTarget(os_tag: std.Target.Os.Tag) RendererBackend {
    return switch (os_tag) {
        .macos => .metal,
        .windows => .vulkan,
        .linux => .vulkan,
        else => .opengl,
    };
}

fn configurePlatform(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    module: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    renderer: RendererBackend,
) void {
    switch (target.result.os.tag) {
        .macos => configureMacOS(b, exe, module, target, optimize, renderer),
        .linux => configureLinux(b, exe, renderer),
        .windows => configureWindows(b, exe, renderer),
        else => @panic("Unsupported operating system"),
    }
}

fn configureMacOS(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    module: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    renderer: RendererBackend,
) void {
    // Build Swift static library
    buildMacOSSwift(b, exe, module, target, optimize);

    // Add frameworks to root_module
    exe.root_module.linkFramework("Foundation", .{});
    exe.root_module.linkFramework("AppKit", .{});
    exe.root_module.linkFramework("QuartzCore", .{});
    exe.root_module.linkFramework("CoreGraphics", .{});

    switch (renderer) {
        .metal => {
            exe.root_module.linkFramework("Metal", .{});
            exe.root_module.linkFramework("MetalKit", .{});
        },
        .opengl => {
            exe.root_module.linkFramework("OpenGL", .{});
        },
        .vulkan => {
            exe.root_module.linkSystemLibrary("vulkan", .{});
            exe.root_module.linkSystemLibrary("MoltenVK", .{});
        },
        .cpu => {},
    }

    // Add include path
    exe.root_module.addIncludePath(b.path("src/platform/macos/include"));
}

fn configureLinux(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    renderer: RendererBackend,
) void {
    _ = b;

    exe.root_module.link_libc = true;
    exe.root_module.linkSystemLibrary("X11", .{});
    exe.root_module.linkSystemLibrary("Xrandr", .{});
    exe.root_module.linkSystemLibrary("Xi", .{});
    exe.root_module.linkSystemLibrary("Xcursor", .{});

    switch (renderer) {
        .vulkan => exe.root_module.linkSystemLibrary("vulkan", .{}),
        .opengl => exe.root_module.linkSystemLibrary("GL", .{}),
        .metal => @panic("Metal is not available on Linux"),
        .cpu => {},
    }
}

fn configureWindows(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    renderer: RendererBackend,
) void {
    _ = b;

    exe.root_module.linkSystemLibrary("user32", .{});
    exe.root_module.linkSystemLibrary("gdi32", .{});
    exe.root_module.linkSystemLibrary("shell32", .{});
    exe.root_module.linkSystemLibrary("kernel32", .{});

    switch (renderer) {
        .vulkan => exe.root_module.linkSystemLibrary("vulkan-1", .{}),
        .opengl => exe.root_module.linkSystemLibrary("opengl32", .{}),
        .metal => @panic("Metal is not available on Windows"),
        .cpu => {},
    }
}

fn buildMacOSSwift(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    module: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    const arch = switch (target.result.cpu.arch) {
        .aarch64 => "arm64",
        .x86_64 => "x86_64",
        else => @panic("Unsupported architecture for macOS"),
    };

    const config = if (optimize == .Debug) "debug" else "release";

    // Build using Swift Package Manager
    const swift_build = b.addSystemCommand(&.{
        "swift",          "build",
        "--package-path", "src/platform/macos",
        "-c",             config,
        "--arch",         arch,
    });
    exe.step.dependOn(&swift_build.step);

    // Path to the built library
    const lib_path = b.fmt("src/platform/macos/.build/{s}/libMacPlatform.a", .{config});

    // Link the library
    module.addObjectFile(b.path(lib_path));

    // Add include path for bridging header
    module.addIncludePath(b.path("src/platform/macos/include"));

    // Link required frameworks
    module.linkFramework("Foundation", .{});
    module.linkFramework("AppKit", .{});
    module.linkFramework("Metal", .{});
    module.linkFramework("MetalKit", .{});
    module.linkFramework("QuartzCore", .{});
    module.linkFramework("CoreGraphics", .{});
}
