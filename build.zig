const std = @import("std");
const builtin = @import("builtin");
const macos = @import("build/macos.zig");
const linux = @import("build/linux.zig");
const windows = @import("build/windows.zig");
const tests = @import("build/tests.zig");

pub const RendererBackend = enum { metal, vulkan, opengl, cpu };

/// Tool modules, used as indices into the modules array.
pub const M = enum(u8) {
    math,
    debug,
    scene_format,
    renderer,
    assets,
    platform,
    ecs,
    action,
    component_registry,
    shape_registry,
    collider_shape_registry,
    registry,
    scene,
    ui,
    systems,
    engine,
    build_options,
};

/// Module definition: source file path + dependencies (by enum).
const ModuleDef = struct {
    name: []const u8,
    path: ?[]const u8, // null for generated modules (build_options)
    deps: []const DepEntry,
};

const DepEntry = struct { []const u8, M };

/// Module graph. Debug is auto-injected into every source module.
const module_defs = [_]ModuleDef{
    // Foundation
    .{ .name = "math", .path = "src/math/math.zig", .deps = &.{} },
    .{
        .name = "debug",
        .path = "src/debug/debug.zig",
        .deps = &.{
            .{ "renderer", .renderer }, .{ "math", .math }, .{ "assets", .assets },
        },
    },
    .{ .name = "scene-format", .path = "src/scene-format/lib.zig", .deps = &.{} },
    // Rendering
    .{
        .name = "renderer",
        .path = "src/renderer/renderer.zig",
        .deps = &.{
            .{ "math", .math },                   .{ "registry", .registry },
            .{ "build_options", .build_options }, .{ "assets", .assets },
        },
    },
    .{
        .name = "assets",
        .path = "src/assets/assets.zig",
        .deps = &.{
            .{ "math", .math }, .{ "renderer", .renderer },
        },
    },
    // Platform
    .{
        .name = "platform",
        .path = "src/platform/platform.zig",
        .deps = &.{
            .{ "math", .math },
        },
    },
    // ECS
    .{
        .name = "ecs",
        .path = "src/ecs/ecs.zig",
        .deps = &.{
            .{ "math", .math },         .{ "renderer", .renderer },
            .{ "assets", .assets },     .{ "action", .action },
            .{ "registry", .registry }, .{ "scene", .scene },
        },
    },
    .{ .name = "action", .path = "src/action/Action.zig", .deps = &.{
        .{ "math", .math },   .{ "platform", .platform }, .{ "ecs", .ecs },
        .{ "scene", .scene },
    } },
    // Registry
    .{
        .name = "component_registry",
        .path = "src/registry/component_registry.zig",
        .deps = &.{
            .{ "scene-format", .scene_format }, .{ "ecs", .ecs },
        },
    },
    .{
        .name = "shape_registry",
        .path = "src/registry/shape_registry.zig",
        .deps = &.{
            .{ "scene-format", .scene_format }, .{ "renderer", .renderer },
            .{ "math", .math },
        },
    },
    .{
        .name = "collider_shape_registry",
        .path = "src/registry/collider_shape_registry.zig",
        .deps = &.{
            .{ "ecs", .ecs },
        },
    },
    .{
        .name = "registry",
        .path = "src/registry/registry.zig",
        .deps = &.{
            .{ "math", .math },         .{ "component_registry", .component_registry },
            .{ "ecs", .ecs },           .{ "collider_shape_registry", .collider_shape_registry },
            .{ "renderer", .renderer }, .{ "shape_registry", .shape_registry },
        },
    },
    // Scene
    .{
        .name = "scene",
        .path = "src/scene/scene.zig",
        .deps = &.{
            .{ "scene-format", .scene_format }, .{ "math", .math },
            .{ "ecs", .ecs },                   .{ "assets", .assets },
            .{ "renderer", .renderer },         .{ "build_options", .build_options },
            .{ "registry", .registry },         .{ "platform", .platform },
            .{ "action", .action },             .{ "engine", .engine },
        },
    },
    // UI
    .{
        .name = "ui",
        .path = "src/ui/ui.zig",
        .deps = &.{
            .{ "math", .math }, .{ "renderer", .renderer }, .{ "assets", .assets },
        },
    },
    // Systems
    .{
        .name = "systems",
        .path = "src/systems/Systems.zig",
        .deps = &.{
            .{ "math", .math },         .{ "ecs", .ecs },
            .{ "renderer", .renderer }, .{ "assets", .assets },
            .{ "action", .action },
        },
    },
    // Engine (top-level)
    .{
        .name = "engine",
        .path = "src/Engine.zig",
        .deps = &.{
            .{ "math", .math },                 .{ "platform", .platform },
            .{ "renderer", .renderer },         .{ "build_options", .build_options },
            .{ "assets", .assets },             .{ "ecs", .ecs },
            .{ "scene-format", .scene_format }, .{ "action", .action },
            .{ "scene", .scene },               .{ "registry", .registry },
            .{ "systems", .systems },
        },
    },

    // Generated (no source file)
    .{ .name = "build_options", .path = null, .deps = &.{} },
};

/// Resolved module pointers, indexed by M enum.
pub const Modules = [std.enums.directEnumArrayLen(M, 0)]*std.Build.Module;

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

    if (selected_renderer == .cpu) {
        std.debug.print(
            \\ERROR: CPU renderer is not currently supported.
            \\      Use -Drenderer=metal for macOS or remove the -Drenderer flag.;
        , .{});
        std.posix.exit(1);
    }

    // Build options (generated module)
    const renderer_options = b.addOptions();
    renderer_options.addOption(RendererBackend, "backend", selected_renderer);
    renderer_options.addOption(bool, "enable_validation", enable_validation);
    const build_options_module = renderer_options.createModule();

    // Platform-specific library (Swift on macOS, null elsewhere)
    const swift_lib = macos.buildSwiftLibrary(b, target, optimize, selected_renderer);

    // ========================================
    // Create all modules + wire dependencies
    // ========================================
    var modules: Modules = undefined;

    // Create all modules from definitions
    inline for (module_defs, 0..) |def, i| {
        if (def.path) |path| {
            modules[i] = b.addModule(def.name, .{
                .root_source_file = b.path(path),
                .target = target,
                .optimize = optimize,
            });
        } else {
            // Generated module (build_options)
            modules[i] = build_options_module;
        }
    }

    // Wire dependencies (debug is auto-injected into every source module)
    const debug_idx = @intFromEnum(M.debug);
    const build_options_idx = @intFromEnum(M.build_options);
    inline for (module_defs, 0..) |def, i| {
        for (def.deps) |dep| {
            modules[i].addImport(dep[0], modules[@intFromEnum(dep[1])]);
        }
        // Auto-inject debug into every source module (except debug itself and build_options)
        if (i != debug_idx and i != build_options_idx and def.path != null) {
            modules[i].addImport("debug", modules[debug_idx]);
        }
    }

    // Platform-specific: include path for Swift bridge header
    modules[@intFromEnum(M.platform)].addIncludePath(b.path("src/platform/macos/swift/include"));

    // Platform linking on modules that need native frameworks
    configurePlatformModule(b, modules[@intFromEnum(M.platform)], target, selected_renderer);
    configurePlatformModule(b, modules[@intFromEnum(M.renderer)], target, selected_renderer);

    // Convenience aliases
    const m = struct {
        fn get(mods: *const Modules, id: M) *std.Build.Module {
            return mods[@intFromEnum(id)];
        }
    };

    // ========================================
    // Engine library
    // ========================================
    const engine_lib = b.addLibrary(.{
        .name = "game-engine",
        .root_module = m.get(&modules, .engine),
    });
    b.installArtifact(engine_lib);

    // ========================================
    // Tool shared app module
    // ========================================
    const app_module = b.createModule(.{
        .root_source_file = b.path("src/tools/app.zig"),
    });
    const tool_deps = [_]M{ .platform, .renderer, .math, .debug, .ui };
    for (tool_deps) |dep| {
        const def = module_defs[@intFromEnum(dep)];
        app_module.addImport(def.name, m.get(&modules, dep));
    }

    // Common tool imports (app + tool_deps + assets)
    const tool_extra_deps = [_]M{ .platform, .renderer, .math, .debug, .assets, .ui };

    // ========================================
    // ZixelArt
    // ========================================
    const zixelart_module = b.addModule("zixelart", .{
        .root_source_file = b.path("src/tools/zixelart/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    zixelart_module.addImport("app", app_module);
    for (tool_extra_deps) |dep| {
        const def = module_defs[@intFromEnum(dep)];
        zixelart_module.addImport(def.name, m.get(&modules, dep));
    }

    const zixelart_exe = b.addExecutable(.{
        .name = "zixelart",
        .root_module = zixelart_module,
    });
    b.installArtifact(zixelart_exe);

    const run_zixelart = b.addRunArtifact(zixelart_exe);
    run_zixelart.step.dependOn(b.getInstallStep());
    run_zixelart.setCwd(b.path("zig-out/bin"));
    b.step("zixelart", "Run the Pixel Art Editor").dependOn(&run_zixelart.step);

    // ========================================
    // UI Playground
    // ========================================
    const ui_playground_module = b.addModule("ui_playground", .{
        .root_source_file = b.path("src/tools/ui_playground/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    ui_playground_module.addImport("app", app_module);
    for (tool_extra_deps) |dep| {
        const def = module_defs[@intFromEnum(dep)];
        ui_playground_module.addImport(def.name, m.get(&modules, dep));
    }

    const ui_playground_exe = b.addExecutable(.{
        .name = "ui-playground",
        .root_module = ui_playground_module,
    });

    const install_ui_playground = b.addInstallArtifact(ui_playground_exe, .{});
    const run_ui_playground = b.addRunArtifact(ui_playground_exe);
    run_ui_playground.step.dependOn(&install_ui_playground.step);
    run_ui_playground.setCwd(b.path("zig-out/bin"));
    b.step("ui", "Run the UI Playground").dependOn(&run_ui_playground.step);

    // ========================================
    // Player (scene viewer / development runtime)
    // ========================================
    const player_module = b.addModule("player", .{
        .root_source_file = b.path("examples/player/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    player_module.addImport("engine", m.get(&modules, .engine));

    const player_exe = b.addExecutable(.{
        .name = "player",
        .root_module = player_module,
    });

    const install_player_assets = b.addInstallDirectory(.{
        .source_dir = b.path("examples/player/assets"),
        .install_dir = .bin,
        .install_subdir = "assets",
    });
    player_exe.step.dependOn(&install_player_assets.step);
    b.installArtifact(player_exe);

    const run_player = b.addRunArtifact(player_exe);
    run_player.step.dependOn(b.getInstallStep());
    run_player.setCwd(b.path("zig-out/bin"));
    b.step("play", "Run the player").dependOn(&run_player.step);

    // ========================================
    // Platform-specific linking (Swift runtime on macOS, no-op elsewhere)
    // ========================================
    linkPlatformLibraries(&.{ engine_lib, zixelart_exe, ui_playground_exe, player_exe }, swift_lib, target);

    // ========================================
    // Clean
    // ========================================
    const clean_step = b.step("clean", "Remove all build artifacts");
    clean_step.dependOn(&b.addRemoveDirTree(.{ .cwd_relative = "zig-out" }).step);
    clean_step.dependOn(&b.addRemoveDirTree(.{ .cwd_relative = ".zig-cache" }).step);

    // ========================================
    // Tests
    // ========================================
    const test_step = b.step("test", "Run all tests");
    const platform_step: ?*std.Build.Step = if (swift_lib) |sl| sl.swift_step else null;
    tests.addAllTests(b, target, optimize, &modules, engine_lib, test_step, platform_step);
}

// ========================================
// Platform helpers
// ========================================

fn defaultRendererForTarget(os_tag: std.Target.Os.Tag) RendererBackend {
    return switch (os_tag) {
        .macos => .metal,
        .windows => .vulkan,
        .linux => .vulkan,
        else => .opengl,
    };
}

/// Link platform libraries onto all executables (Swift runtime on macOS, no-op elsewhere).
fn linkPlatformLibraries(
    artifacts: []const *std.Build.Step.Compile,
    swift_lib: ?macos.SwiftBuildResult,
    target: std.Build.ResolvedTarget,
) void {
    switch (target.result.os.tag) {
        .macos => for (artifacts) |artifact| {
            macos.linkSwiftLibrary(artifact, swift_lib, target);
        },
        else => {},
    }
}

/// Link platform-specific native libraries onto a module.
fn configurePlatformModule(
    b: *std.Build,
    module: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    renderer: RendererBackend,
) void {
    switch (target.result.os.tag) {
        .macos => macos.configureModule(b, module, target, renderer),
        .linux => linux.configureModule(module, renderer),
        .windows => windows.configureModule(module, renderer),
        else => @panic("Unsupported operating system"),
    }
}
