const std = @import("std");
const builtin = @import("builtin");

const RendererBackend = enum { metal, vulkan, opengl, cpu };

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

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

    const selected_renderer = renderer_backend orelse defaultRendererForTarget(target.result.os.tag);

    const core_module = b.addModule("core", .{
        .root_source_file = b.path("src/core/types.zig"),
    });

    const asset_module = b.addModule("asset", .{
        .root_source_file = b.path("src/assets/assets.zig"),
    });
    asset_module.addImport("core", core_module);

    const renderer_module = b.addModule("renderer", .{
        .root_source_file = b.path("src/renderer/renderer.zig"),
    });
    renderer_module.addImport("core", core_module);

    const renderer_options = b.addOptions();
    renderer_options.addOption(RendererBackend, "backend", selected_renderer);
    renderer_options.addOption(bool, "enable_validation", enable_validation);
    renderer_module.addImport("asset", asset_module);

    const build_options_module = renderer_options.createModule();
    renderer_module.addImport("build_options", build_options_module);

    const platform_module = b.addModule("platform", .{
        .root_source_file = b.path("src/platform/platform.zig"),
    });
    platform_module.addIncludePath(b.path("src/platform/macos/swift/include"));

    // TODO: This is probably the end for the engine 'library'
    const api_module = b.addModule("api", .{
        .root_source_file = b.path("src/api/engine.zig"),
    });
    api_module.addImport("core", core_module);
    api_module.addImport("platform", platform_module);
    api_module.addImport("renderer", renderer_module);
    api_module.addImport("build_options", build_options_module);
    api_module.addImport("asset", asset_module);

    // Main is floating around for dev/testing
    const main_module = b.addModule("main", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    main_module.addImport("core", core_module);
    main_module.addImport("platform", platform_module);
    main_module.addImport("renderer", renderer_module);
    main_module.addImport("api", api_module);

    const exe = b.addExecutable(.{
        .name = "game-engine",
        .root_module = main_module,
    });

    exe.root_module.addImport("core", core_module);
    exe.root_module.addImport("platform", platform_module);
    exe.root_module.addImport("renderer", renderer_module);
    exe.root_module.addImport("api", api_module);

    configurePlatform(b, exe, main_module, target, optimize, selected_renderer);

    b.installArtifact(exe);

    const clean_step = b.step("clean", "Remove all build artifacts");
    const remove_swift = b.addRemoveDirTree(.{ .cwd_relative = "zig-out/swift-build" });
    clean_step.dependOn(&remove_swift.step);

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

    exe.root_module.addIncludePath(b.path("src/platform/macos/include"));

    module.linkFramework("AppKit", .{});
    module.linkFramework("Metal", .{});
    module.linkFramework("MetalKit", .{});
    module.linkFramework("QuartzCore", .{});
    module.linkFramework("CoreGraphics", .{});

    const sys_path = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.sdk/usr/lib/swift/";
    const other_sys_path = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx";
    exe.root_module.addLibraryPath(.{ .cwd_relative = sys_path });
    exe.root_module.addLibraryPath(.{ .cwd_relative = other_sys_path });

    exe.linkSystemLibrary("c++");
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
    exe.root_module.linkSystemLibrary("swiftMetalKit", .{});
    exe.root_module.linkSystemLibrary("swiftModelIO", .{});
    exe.root_module.linkSystemLibrary("swiftIOKit", .{});
    exe.root_module.linkSystemLibrary("swiftXPC", .{});
    exe.root_module.linkSystemLibrary("swiftDarwin", .{});
    exe.root_module.linkSystemLibrary("swiftCoreImage", .{});
    exe.root_module.linkSystemLibrary("swiftQuartzCore", .{});
    exe.root_module.linkSystemLibrary("swiftOSLog", .{});
    exe.root_module.linkSystemLibrary("swiftos", .{});
    exe.root_module.linkSystemLibrary("swiftsimd", .{});
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

    const swift_scratch = b.fmt("zig-out/swift-build/{s}", .{config});

    const swift_build = b.addSystemCommand(&.{
        "swift",          "build",
        "--package-path", "src/platform/macos",
        "--scratch-path", swift_scratch,
        "-c",             config,
        "--arch",         arch,
    });

    const metal_compile = b.addSystemCommand(&.{
        "xcrun", "-sdk",                                    "macosx", "metal",
        "-c",    "src/platform//macos/swift/shaders.metal", "-o",     "zig-out/shaders.air",
    });
    metal_compile.step.dependOn(&swift_build.step);

    const metal_lib = b.addSystemCommand(&.{
        "xcrun",               "-sdk", "macosx",                       "metallib",
        "zig-out/shaders.air", "-o",   "zig-out/lib/default.metallib",
    });
    metal_lib.step.dependOn(&metal_compile.step);

    const install_metallib = b.addInstallFile(.{ .cwd_relative = "zig-out/lib/default.metallib" }, "bin/default.metallib");
    install_metallib.step.dependOn(&metal_lib.step);

    const swift_clean = b.addSystemCommand(&.{ "rm", "-rf", "./src/platform/macos/.build/" });
    exe.step.dependOn(&swift_build.step);
    exe.step.dependOn(&swift_clean.step);

    const lib_src = b.fmt("{s}/arm64-apple-macosx/{s}/libMacPlatform.a", .{ swift_scratch, config });
    const lib_dest = "lib/libMacPlatform.a";

    const install_lib = b.addInstallFile(.{ .cwd_relative = lib_src }, lib_dest);
    install_lib.step.dependOn(&swift_build.step);
    exe.step.dependOn(&install_lib.step);
    exe.step.dependOn(&install_metallib.step);

    module.addObjectFile(b.path(b.fmt("zig-out/{s}", .{lib_dest})));
}
