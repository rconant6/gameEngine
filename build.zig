const std = @import("std");
const builtin = @import("builtin");

const RendererBackend = enum { metal, vulkan, opengl, cpu };
const MinLogLevel = enum { debug, info, warn, err, fatal };

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

    const scene_format_module = b.addModule("scene-format", .{
        .root_source_file = b.path("src/scene-format/lib.zig"),
    });

    const renderer_module = b.addModule("renderer", .{
        .root_source_file = b.path("src/renderer/renderer.zig"),
    });
    renderer_module.addImport("core", core_module);

    const asset_module = b.addModule("asset", .{
        .root_source_file = b.path("src/assets/assets.zig"),
    });
    asset_module.addImport("core", core_module);
    asset_module.addImport("renderer", renderer_module);

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
    platform_module.addImport("build_options", build_options_module);

    const entity_module = b.addModule("entity", .{
        .root_source_file = b.path("src/ecs/ecs.zig"),
    });
    entity_module.addImport("core", core_module);
    entity_module.addImport("renderer", renderer_module);
    entity_module.addImport("asset", asset_module);

    const internal_module = b.addModule("internal", .{
        .root_source_file = b.path("src/internal/internal.zig"),
    });
    internal_module.addImport("platform", platform_module);
    internal_module.addImport("core", core_module);
    internal_module.addImport("entity", entity_module);

    const action_module = b.addModule("action", .{
        .root_source_file = b.path("src/action/Action.zig"),
    });
    action_module.addImport("core", core_module);
    action_module.addImport("entity", entity_module);
    action_module.addImport("platform", platform_module);
    action_module.addImport("internal", internal_module);

    entity_module.addImport("internal", internal_module);
    entity_module.addImport("action", action_module);

    // Internal error logger module
    const error_logger_module = b.addModule("error_logger", .{
        .root_source_file = b.path("src/internal/error_logger.zig"),
    });

    // Scene internal modules
    const component_registry_module = b.addModule("component_registry", .{
        .root_source_file = b.path("src/scene/component_registry.zig"),
    });
    component_registry_module.addImport("scene-format", scene_format_module);
    component_registry_module.addImport("entity", entity_module);

    const shape_registry_module = b.addModule("shape_registry", .{
        .root_source_file = b.path("src/scene/shape_registry.zig"),
    });
    shape_registry_module.addImport("scene-format", scene_format_module);
    shape_registry_module.addImport("renderer", renderer_module);

    const collider_shape_registry_module = b.addModule("collider_shape_registry", .{
        .root_source_file = b.path("src/scene/collider_shape_registry.zig"),
    });
    collider_shape_registry_module.addImport("entity", entity_module);

    // Scene modules
    const scene_manager_module = b.addModule("scene_manager", .{
        .root_source_file = b.path("src/scene/manager.zig"),
    });
    scene_manager_module.addImport("scene-format", scene_format_module);

    const scene_instantiator_module = b.addModule("scene_instantiator", .{
        .root_source_file = b.path("src/scene/instantiator.zig"),
    });
    scene_instantiator_module.addImport("scene-format", scene_format_module);
    scene_instantiator_module.addImport("core", core_module);
    scene_instantiator_module.addImport("entity", entity_module);
    scene_instantiator_module.addImport("asset", asset_module);
    scene_instantiator_module.addImport("renderer", renderer_module);
    scene_instantiator_module.addImport("build_options", build_options_module);
    scene_instantiator_module.addImport("component_registry", component_registry_module);
    scene_instantiator_module.addImport("shape_registry", shape_registry_module);
    scene_instantiator_module.addImport("collider_shape_registry", collider_shape_registry_module);
    scene_instantiator_module.addImport("platform", platform_module);

    // Engine public API
    const engine_module = b.addModule("engine", .{
        .root_source_file = b.path("src/engine.zig"),
    });

    // Scene instantiator needs the Engine type
    scene_instantiator_module.addImport("engine", engine_module);

    // Engine module dependencies
    engine_module.addImport("core", core_module);
    engine_module.addImport("platform", platform_module);
    engine_module.addImport("renderer", renderer_module);
    engine_module.addImport("build_options", build_options_module);
    engine_module.addImport("asset", asset_module);
    engine_module.addImport("entity", entity_module);
    engine_module.addImport("internal", internal_module);
    engine_module.addImport("scene-format", scene_format_module);
    engine_module.addImport("error_logger", error_logger_module);
    engine_module.addImport("action", action_module);

    // Engine owns scene management internally - games don't need to import these
    engine_module.addImport("scene_instantiator", scene_instantiator_module);
    engine_module.addImport("scene_manager", scene_manager_module);
    engine_module.addImport("component_registry", component_registry_module);
    engine_module.addImport("shape_registry", shape_registry_module);

    // ========================================
    // Test Game Executable
    // ========================================
    const test_game_module = b.addModule("test_game", .{
        .root_source_file = b.path("examples/test_game/main.zig"),
        // .root_source_file = b.path("examples/test_game/action_test_scenario.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_game_module.addImport("engine", engine_module);

    const test_game_exe = b.addExecutable(.{
        .name = "test-game",
        .root_module = test_game_module,
    });

    configurePlatform(b, test_game_exe, test_game_module, target, optimize, selected_renderer);

    const install_test_game_assets = b.addInstallDirectory(.{
        .source_dir = b.path("examples/test_game/assets"),
        .install_dir = .bin,
        .install_subdir = "assets",
    });
    test_game_exe.step.dependOn(&install_test_game_assets.step);

    b.installArtifact(test_game_exe);

    const run_test_game = b.addRunArtifact(test_game_exe);
    run_test_game.step.dependOn(b.getInstallStep());
    run_test_game.setCwd(b.path("zig-out/bin"));

    const run_test_game_step = b.step("run-test-game", "Run the test game");
    run_test_game_step.dependOn(&run_test_game.step);

    // Clean step for Swift build artifacts
    const clean_step = b.step("clean", "Remove all swift build artifacts");
    const remove_swift = b.addRemoveDirTree(.{ .cwd_relative = "zig-out/swift-build" });
    clean_step.dependOn(&remove_swift.step);

    // ========================================
    // Test Frameworks
    // ========================================
    const test_step = b.step("test", "Run all tests");

    // ========================================
    // Layer 1: Core V2 Tests
    // ========================================
    const v2_test_module = b.addModule("v2_tests", .{
        .root_source_file = b.path("tests/core/test_v2.zig"),
        .target = target,
        .optimize = optimize,
    });
    v2_test_module.addAnonymousImport("V2", .{
        .root_source_file = b.path("src/core/V2.zig"),
    });

    const v2_tests = b.addTest(.{
        .name = "v2-tests",
        .root_module = v2_test_module,
    });
    const run_v2_tests = b.addRunArtifact(v2_tests);

    // ========================================
    // Layer 2: ECS Component Tests
    // ========================================
    // ECS Component Storage Tests
    const ecs_test_module = b.addModule("ecs_tests", .{
        .root_source_file = b.path("tests/ecs/test_component_storage.zig"),
        .target = target,
        .optimize = optimize,
    });
    ecs_test_module.addImport("core", core_module);
    ecs_test_module.addAnonymousImport("ComponentStorage", .{
        .root_source_file = b.path("src/ecs/ComponentStorage.zig"),
    });

    const ecs_tests = b.addTest(.{
        .name = "ecs-tests",
        .root_module = ecs_test_module,
    });
    const run_ecs_tests = b.addRunArtifact(ecs_tests);

    // Query Tests - use entity module which properly exports Query and ComponentStorage
    const query_test_module = b.addModule("query_tests", .{
        .root_source_file = b.path("tests/ecs/test_query.zig"),
        .target = target,
        .optimize = optimize,
    });
    query_test_module.addImport("core", core_module);
    query_test_module.addImport("entity", entity_module);

    const query_tests = b.addTest(.{
        .name = "query-tests",
        .root_module = query_test_module,
    });
    const run_query_tests = b.addRunArtifact(query_tests);

    // World Tests
    const world_test_module = b.addModule("world_tests", .{
        .root_source_file = b.path("tests/ecs/test_world.zig"),
        .target = target,
        .optimize = optimize,
    });
    world_test_module.addImport("core", core_module);
    world_test_module.addAnonymousImport("World", .{
        .root_source_file = b.path("src/ecs/World.zig"),
    });
    world_test_module.addAnonymousImport("Entity", .{
        .root_source_file = b.path("src/ecs/Entity.zig"),
    });
    world_test_module.addAnonymousImport("ComponentStorage", .{
        .root_source_file = b.path("src/ecs/ComponentStorage.zig"),
    });
    world_test_module.addAnonymousImport("Query", .{
        .root_source_file = b.path("src/ecs/Query.zig"),
    });
    const world_tests = b.addTest(.{
        .name = "world-tests",
        .root_module = world_test_module,
    });
    const run_world_tests = b.addRunArtifact(world_tests);

    // Collider Component Tests
    const collider_test_module = b.addModule("collider_tests", .{
        .root_source_file = b.path("tests/ecs/test_collider.zig"),
        .target = target,
        .optimize = optimize,
    });
    collider_test_module.addAnonymousImport("collider", .{
        .root_source_file = b.path("src/ecs/collider.zig"),
    });

    const collider_tests = b.addTest(.{
        .name = "collider-tests",
        .root_module = collider_test_module,
    });
    const run_collider_tests = b.addRunArtifact(collider_tests);

    // Tag Component Tests
    const tag_test_module = b.addModule("tag_tests", .{
        .root_source_file = b.path("tests/ecs/test_tag.zig"),
        .target = target,
        .optimize = optimize,
    });
    tag_test_module.addAnonymousImport("Tag", .{
        .root_source_file = b.path("src/ecs/Tag.zig"),
    });

    const tag_tests = b.addTest(.{
        .name = "tag-tests",
        .root_module = tag_test_module,
    });
    const run_tag_tests = b.addRunArtifact(tag_tests);

    // Action Tests

    const action_test_module = b.addModule("action_tests", .{
        .root_source_file = b.path("tests/ecs/test_action.zig"),
        .target = target,
        .optimize = optimize,
    });
    action_test_module.addImport("core", core_module);
    action_test_module.addImport("Action", action_module);

    const action_tests = b.addTest(.{
        .name = "action-tests",
        .root_module = action_test_module,
    });
    const run_action_tests = b.addRunArtifact(action_tests);

    // ActionBindings Tests
    const triggers_module = b.addModule("triggers", .{
        .root_source_file = b.path("src/action/Triggers.zig"),
    });
    triggers_module.addImport("core", core_module);
    triggers_module.addImport("action", action_module);
    triggers_module.addImport("platform", platform_module);
    triggers_module.addImport("entity", entity_module);

    const action_bindings_module = b.addModule("ActionBindings", .{
        .root_source_file = b.path("src/action/ActionBindings.zig"),
    });
    action_bindings_module.addImport("core", core_module);
    action_bindings_module.addImport("triggers", triggers_module);

    const action_bindings_test_module = b.addModule("action_bindings_tests", .{
        .root_source_file = b.path("tests/ecs/test_action_bindings.zig"),
        .target = target,
        .optimize = optimize,
    });
    action_bindings_test_module.addImport("core", core_module);
    action_bindings_test_module.addImport("Action", action_module);

    const action_bindings_tests = b.addTest(.{
        .name = "action-bindings-tests",
        .root_module = action_bindings_test_module,
    });
    const run_action_bindings_tests = b.addRunArtifact(action_bindings_tests);

    // CollisionTrigger Tests
    const collision_trigger_test_module = b.addModule("collision_trigger_tests", .{
        .root_source_file = b.path("tests/ecs/test_collision_trigger.zig"),
        .target = target,
        .optimize = optimize,
    });
    collision_trigger_test_module.addImport("core", core_module);
    collision_trigger_test_module.addImport("Action", action_module);

    const collision_trigger_tests = b.addTest(.{
        .name = "collision-trigger-tests",
        .root_module = collision_trigger_test_module,
    });
    const run_collision_trigger_tests = b.addRunArtifact(collision_trigger_tests);

    // InputTrigger Tests
    const input_trigger_test_module = b.addModule("input_trigger_tests", .{
        .root_source_file = b.path("tests/ecs/test_input_trigger.zig"),
        .target = target,
        .optimize = optimize,
    });
    input_trigger_test_module.addImport("core", core_module);
    input_trigger_test_module.addImport("Action", action_module);
    input_trigger_test_module.addImport("platform", platform_module);

    const input_trigger_tests = b.addTest(.{
        .name = "input-trigger-tests",
        .root_module = input_trigger_test_module,
    });
    const run_input_trigger_tests = b.addRunArtifact(input_trigger_tests);

    // TimeTrigger Tests (Custom Trigger System)
    const time_trigger_test_module = b.addModule("time_trigger_tests", .{
        .root_source_file = b.path("tests/ecs/test_time_trigger.zig"),
        .target = target,
        .optimize = optimize,
    });
    time_trigger_test_module.addImport("core", core_module);
    time_trigger_test_module.addImport("Action", action_module);
    time_trigger_test_module.addImport("entity", entity_module);

    const time_trigger_tests = b.addTest(.{
        .name = "time-trigger-tests",
        .root_module = time_trigger_test_module,
    });
    const run_time_trigger_tests = b.addRunArtifact(time_trigger_tests);

    // ========================================
    // Layer 3: Collision Detection Tests
    // ========================================
    const collision_detection_module = b.addModule("CollisionDetection", .{
        .root_source_file = b.path("src/internal/CollisionDetection.zig"),
    });
    collision_detection_module.addImport("core", core_module);
    collision_detection_module.addImport("entity", entity_module);

    const collision_test_module = b.addModule("collision_tests", .{
        .root_source_file = b.path("tests/collision/test_collision_detection.zig"),
        .target = target,
        .optimize = optimize,
    });
    collision_test_module.addImport("core", core_module);
    collision_test_module.addImport("entity", entity_module);
    collision_test_module.addImport("CollisionDetection", collision_detection_module);

    const collision_tests = b.addTest(.{
        .name = "collision-tests",
        .root_module = collision_test_module,
    });
    const run_collision_tests = b.addRunArtifact(collision_tests);

    // ========================================
    // Layer 4: Scene Format Tests
    // ========================================
    // Scene Format Lexer Tests
    const scene_lexer_test_module = b.addModule("scene_lexer_tests", .{
        .root_source_file = b.path("tests/scene-format/lexer_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    scene_lexer_test_module.addImport("scene-format", scene_format_module);

    const scene_lexer_tests = b.addTest(.{
        .name = "scene-lexer-tests",
        .root_module = scene_lexer_test_module,
    });
    const run_scene_lexer_tests = b.addRunArtifact(scene_lexer_tests);

    // Scene Format Parser Tests
    const scene_parser_test_module = b.addModule("scene_parser_tests", .{
        .root_source_file = b.path("tests/scene-format/parser_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    scene_parser_test_module.addImport("scene-format", scene_format_module);

    const scene_parser_tests = b.addTest(.{
        .name = "scene-parser-tests",
        .root_module = scene_parser_test_module,
    });
    const run_scene_parser_tests = b.addRunArtifact(scene_parser_tests);

    // Template Parser Tests (will fail until template support is added)
    const template_parser_test_module = b.addModule("template_parser_tests", .{
        .root_source_file = b.path("tests/scene-format/template_parser_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    template_parser_test_module.addImport("scene-format", scene_format_module);

    const template_parser_tests = b.addTest(.{
        .name = "template-parser-tests",
        .root_module = template_parser_test_module,
    });
    const run_template_parser_tests = b.addRunArtifact(template_parser_tests);

    // Scene Integration Tests
    const scene_test_module = b.addModule("scene_tests", .{
        .root_source_file = b.path("tests/scene/test_scene_integration.zig"),
        .target = target,
        .optimize = optimize,
    });
    scene_test_module.addImport("scene-format", scene_format_module);

    const scene_tests = b.addTest(.{
        .name = "scene-tests",
        .root_module = scene_test_module,
    });
    const run_scene_tests = b.addRunArtifact(scene_tests);

    // Template Instantiation Tests (will fail until template system is implemented)
    const template_instantiation_test_module = b.addModule("template_instantiation_tests", .{
        .root_source_file = b.path("tests/scene/test_template_instantiation.zig"),
        .target = target,
        .optimize = optimize,
    });
    template_instantiation_test_module.addImport("scene-format", scene_format_module);
    template_instantiation_test_module.addImport("entity", entity_module);

    const template_instantiation_tests = b.addTest(.{
        .name = "template-instantiation-tests",
        .root_module = template_instantiation_test_module,
    });
    const run_template_instantiation_tests = b.addRunArtifact(template_instantiation_tests);

    // ========================================
    // Layer 4B: Renderer Tests
    // ========================================
    const color_test_module = b.addModule("color_tests", .{
        .root_source_file = b.path("tests/renderer/test_color.zig"),
        .target = target,
        .optimize = optimize,
    });
    color_test_module.addAnonymousImport("color", .{
        .root_source_file = b.path("src/renderer/color.zig"),
    });

    const color_tests = b.addTest(.{
        .name = "color-tests",
        .root_module = color_test_module,
    });
    const run_color_tests = b.addRunArtifact(color_tests);

    const core_shapes_module = b.addModule("core_shapes", .{
        .root_source_file = b.path("src/renderer/core_shapes.zig"),
    });
    core_shapes_module.addImport("core", core_module);

    const shapes_test_module = b.addModule("shapes_tests", .{
        .root_source_file = b.path("tests/renderer/test_shapes.zig"),
        .target = target,
        .optimize = optimize,
    });
    shapes_test_module.addImport("core", core_module);
    shapes_test_module.addImport("core_shapes", core_shapes_module);

    const shapes_tests = b.addTest(.{
        .name = "shapes-tests",
        .root_module = shapes_test_module,
    });
    const run_shapes_tests = b.addRunArtifact(shapes_tests);

    // ========================================
    // Layer 5: End-to-End Integration Tests
    // ========================================
    const integration_test_module = b.addModule("integration_tests", .{
        .root_source_file = b.path("tests/integration/test_end_to_end.zig"),
        .target = target,
        .optimize = optimize,
    });
    integration_test_module.addImport("core", core_module);
    integration_test_module.addImport("entity", entity_module);
    integration_test_module.addImport("CollisionDetection", collision_detection_module);

    const integration_tests = b.addTest(.{
        .name = "integration-tests",
        .root_module = integration_test_module,
    });
    const run_integration_tests = b.addRunArtifact(integration_tests);

    // ========================================
    // Register all test suites
    // ========================================
    test_step.dependOn(&run_v2_tests.step);
    test_step.dependOn(&run_ecs_tests.step);
    test_step.dependOn(&run_query_tests.step);
    test_step.dependOn(&run_world_tests.step);
    test_step.dependOn(&run_collider_tests.step);
    test_step.dependOn(&run_tag_tests.step);
    test_step.dependOn(&run_action_tests.step);
    test_step.dependOn(&run_action_bindings_tests.step);
    test_step.dependOn(&run_collision_trigger_tests.step);
    test_step.dependOn(&run_input_trigger_tests.step);
    test_step.dependOn(&run_time_trigger_tests.step);
    test_step.dependOn(&run_collision_tests.step);
    test_step.dependOn(&run_scene_lexer_tests.step);
    test_step.dependOn(&run_scene_parser_tests.step);
    test_step.dependOn(&run_template_parser_tests.step);
    test_step.dependOn(&run_scene_tests.step);
    test_step.dependOn(&run_template_instantiation_tests.step);
    test_step.dependOn(&run_color_tests.step);
    test_step.dependOn(&run_shapes_tests.step);
    test_step.dependOn(&run_integration_tests.step);
}

pub fn defaultRendererForTarget(os_tag: std.Target.Os.Tag) RendererBackend {
    return switch (os_tag) {
        .macos => .metal,
        .windows => .vulkan,
        .linux => .vulkan,
        else => .opengl,
    };
}

pub fn configurePlatform(
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

pub fn configureMacOS(
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

pub fn configureLinux(
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

pub fn configureWindows(
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

pub fn buildMacOSSwift(
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
