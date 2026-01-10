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
        .target = target,
        .optimize = optimize,
    });

    const scene_format_module = b.addModule("scene-format", .{
        .root_source_file = b.path("src/scene-format/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    const renderer_module = b.addModule("renderer", .{
        .root_source_file = b.path("src/renderer/renderer.zig"),
        .target = target,
        .optimize = optimize,
    });
    renderer_module.addImport("core", core_module);

    const asset_module = b.addModule("asset", .{
        .root_source_file = b.path("src/assets/assets.zig"),
        .target = target,
        .optimize = optimize,
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
        .target = target,
        .optimize = optimize,
    });
    platform_module.addIncludePath(b.path("src/platform/macos/swift/include"));
    platform_module.addImport("build_options", build_options_module);

    // Configure platform-specific linking on the platform module
    configurePlatformModule(b, platform_module, target, optimize, selected_renderer);

    // Configure platform-specific linking on the renderer module (needs Metal frameworks)
    configurePlatformModule(b, renderer_module, target, optimize, selected_renderer);

    // Core needs platform for Input.zig
    core_module.addImport("platform", platform_module);

    const entity_module = b.addModule("entity", .{
        .root_source_file = b.path("src/ecs/ecs.zig"),
        .target = target,
        .optimize = optimize,
    });
    entity_module.addImport("core", core_module);
    entity_module.addImport("renderer", renderer_module);
    entity_module.addImport("asset", asset_module);

    // Core needs entity for CollisionDetection.zig and shape_registry.zig needs renderer
    core_module.addImport("entity", entity_module);
    core_module.addImport("renderer", renderer_module);

    const action_module = b.addModule("action", .{
        .root_source_file = b.path("src/action/Action.zig"),
        .target = target,
        .optimize = optimize,
    });
    action_module.addImport("core", core_module);
    action_module.addImport("entity", entity_module);
    action_module.addImport("platform", platform_module);

    entity_module.addImport("action", action_module);

    // Core registry modules (already exported via core.zig but needed for separate imports)
    const component_registry_module = b.addModule("component_registry", .{
        .root_source_file = b.path("src/core/component_registry.zig"),
        .target = target,
        .optimize = optimize,
    });
    component_registry_module.addImport("scene-format", scene_format_module);
    component_registry_module.addImport("entity", entity_module);
    const shape_registry_module = b.addModule("shape_registry", .{
        .root_source_file = b.path("src/core/shape_registry.zig"),
        .target = target,
        .optimize = optimize,
    });
    shape_registry_module.addImport("scene-format", scene_format_module);
    shape_registry_module.addImport("renderer", renderer_module);
    const collider_shape_registry_module = b.addModule("collider_shape_registry", .{
        .root_source_file = b.path("src/core/collider_shape_registry.zig"),
        .target = target,
        .optimize = optimize,
    });
    collider_shape_registry_module.addImport("entity", entity_module);

    // Scene modules
    const scene_module = b.addModule("scene", .{
        .root_source_file = b.path("src/scene/scene.zig"),
        .target = target,
        .optimize = optimize,
    });
    scene_module.addImport("scene-format", scene_format_module);
    scene_module.addImport("core", core_module);
    scene_module.addImport("entity", entity_module);
    scene_module.addImport("asset", asset_module);
    scene_module.addImport("renderer", renderer_module);
    scene_module.addImport("build_options", build_options_module);
    scene_module.addImport("component_registry", component_registry_module);
    scene_module.addImport("shape_registry", shape_registry_module);
    scene_module.addImport("collider_shape_registry", collider_shape_registry_module);
    scene_module.addImport("platform", platform_module);
    scene_module.addImport("action", action_module);

    entity_module.addImport("scene", scene_module);
    // ========================================
    // Engine Module and Library
    // ========================================
    const engine_module = b.addModule("engine", .{
        .root_source_file = b.path("src/engine.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add all module dependencies
    engine_module.addImport("core", core_module);
    engine_module.addImport("platform", platform_module);
    engine_module.addImport("renderer", renderer_module);
    engine_module.addImport("build_options", build_options_module);
    engine_module.addImport("asset", asset_module);
    engine_module.addImport("entity", entity_module);
    engine_module.addImport("scene-format", scene_format_module);
    engine_module.addImport("action", action_module);
    engine_module.addImport("scene", scene_module);
    engine_module.addImport("component_registry", component_registry_module);
    engine_module.addImport("shape_registry", shape_registry_module);

    // Scene instantiator needs the Engine type
    scene_module.addImport("engine", engine_module);

    entity_module.addImport("scene", scene_module);

    // Create a static library for the engine
    const engine_lib = b.addLibrary(.{
        .name = "game-engine",
        .root_module = engine_module,
    });

    // Configure platform-specific linking and build steps for the engine library
    configurePlatform(b, engine_lib, engine_module, target, optimize, selected_renderer);

    // Install the engine library
    b.installArtifact(engine_lib);

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
    query_tests.linkLibrary(engine_lib);
    const run_query_tests = b.addRunArtifact(query_tests);

    // World Tests
    const world_test_module = b.addModule("world_tests", .{
        .root_source_file = b.path("tests/ecs/test_world.zig"),
        .target = target,
        .optimize = optimize,
    });
    world_test_module.addImport("core", core_module);
    world_test_module.addImport("scene", scene_module);
    world_test_module.addImport("entity", entity_module);
    const world_tests = b.addTest(.{
        .name = "world-tests",
        .root_module = world_test_module,
    });
    world_tests.linkLibrary(engine_lib);
    const run_world_tests = b.addRunArtifact(world_tests);

    // Collider Component Tests
    const collider_test_module = b.addModule("collider_tests", .{
        .root_source_file = b.path("tests/ecs/test_collider.zig"),
        .target = target,
        .optimize = optimize,
    });
    collider_test_module.addImport("core", core_module);
    collider_test_module.addImport("entity", entity_module);

    const collider_tests = b.addTest(.{
        .name = "collider-tests",
        .root_module = collider_test_module,
    });
    collider_tests.linkLibrary(engine_lib);
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
    action_tests.linkLibrary(engine_lib);
    const run_action_tests = b.addRunArtifact(action_tests);

    // ActionBindings Tests
    const triggers_module = b.addModule("triggers", .{
        .root_source_file = b.path("src/action/Triggers.zig"),
        .target = target,
        .optimize = optimize,
    });
    triggers_module.addImport("core", core_module);
    triggers_module.addImport("action", action_module);
    triggers_module.addImport("platform", platform_module);
    triggers_module.addImport("entity", entity_module);

    const action_bindings_module = b.addModule("ActionBindings", .{
        .root_source_file = b.path("src/action/ActionBindings.zig"),
        .target = target,
        .optimize = optimize,
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
    action_bindings_tests.linkLibrary(engine_lib);
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
    collision_trigger_tests.linkLibrary(engine_lib);
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
    input_trigger_tests.linkLibrary(engine_lib);
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
    time_trigger_tests.linkLibrary(engine_lib);
    const run_time_trigger_tests = b.addRunArtifact(time_trigger_tests);

    // ========================================
    // Layer 3: Collision Detection Tests
    // ========================================
    const collision_test_module = b.addModule("collision_tests", .{
        .root_source_file = b.path("tests/collision/test_collision_detection.zig"),
        .target = target,
        .optimize = optimize,
    });
    collision_test_module.addImport("core", core_module);
    collision_test_module.addImport("entity", entity_module);

    const collision_tests = b.addTest(.{
        .name = "collision-tests",
        .root_module = collision_test_module,
    });
    collision_tests.linkLibrary(engine_lib);
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

    // Nested Block Parser Tests (will fail until nested block support is added)
    const nested_block_parser_test_module = b.addModule("nested_block_parser_tests", .{
        .root_source_file = b.path("tests/scene-format/parser_nested_blocks_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    nested_block_parser_test_module.addImport("scene-format", scene_format_module);

    const nested_block_parser_tests = b.addTest(.{
        .name = "nested-block-parser-tests",
        .root_module = nested_block_parser_test_module,
    });
    const run_nested_block_parser_tests = b.addRunArtifact(nested_block_parser_tests);

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

    const template_instantiation_test_module = b.addModule("template_instantiation_tests", .{
        .root_source_file = b.path("tests/scene/test_template_instantiation.zig"),
        .target = target,
        .optimize = optimize,
    });
    template_instantiation_test_module.addImport("scene-format", scene_format_module);
    template_instantiation_test_module.addImport("entity", entity_module);
    template_instantiation_test_module.addImport("scene", scene_module);
    template_instantiation_test_module.addImport("asset", asset_module);
    template_instantiation_test_module.addImport("core", core_module);

    const template_instantiation_tests = b.addTest(.{
        .name = "template-instantiation-tests",
        .root_module = template_instantiation_test_module,
    });
    template_instantiation_tests.linkLibrary(engine_lib);
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

    const shapes_test_module = b.addModule("shapes_tests", .{
        .root_source_file = b.path("tests/renderer/test_shapes.zig"),
        .target = target,
        .optimize = optimize,
    });
    shapes_test_module.addImport("core", core_module);
    shapes_test_module.addImport("renderer", renderer_module);

    const shapes_tests = b.addTest(.{
        .name = "shapes-tests",
        .root_module = shapes_test_module,
    });
    shapes_tests.linkLibrary(engine_lib);
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

    const integration_tests = b.addTest(.{
        .name = "integration-tests",
        .root_module = integration_test_module,
    });
    integration_tests.linkLibrary(engine_lib);
    const run_integration_tests = b.addRunArtifact(integration_tests);

    // ========================================
    // Register all test suites
    // ========================================
    test_step.dependOn(&run_v2_tests.step);
    test_step.dependOn(&run_color_tests.step);
    test_step.dependOn(&run_scene_lexer_tests.step);
    test_step.dependOn(&run_scene_parser_tests.step);
    test_step.dependOn(&run_template_parser_tests.step);
    test_step.dependOn(&run_tag_tests.step);
    test_step.dependOn(&run_ecs_tests.step);
    test_step.dependOn(&run_query_tests.step);
    test_step.dependOn(&run_world_tests.step);
    test_step.dependOn(&run_collider_tests.step);
    test_step.dependOn(&run_action_tests.step);
    test_step.dependOn(&run_action_bindings_tests.step);
    test_step.dependOn(&run_collision_trigger_tests.step);
    test_step.dependOn(&run_input_trigger_tests.step);
    test_step.dependOn(&run_time_trigger_tests.step);
    test_step.dependOn(&run_collision_tests.step);
    test_step.dependOn(&run_nested_block_parser_tests.step);
    test_step.dependOn(&run_scene_tests.step);
    test_step.dependOn(&run_shapes_tests.step);
    test_step.dependOn(&run_integration_tests.step);
    test_step.dependOn(&run_template_instantiation_tests.step);
}

/// Configure a module with all platform-specific linking requirements
/// This ensures any executable that imports this module gets all necessary frameworks and libraries
pub fn configurePlatformModule(
    b: *std.Build,
    module: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    renderer: RendererBackend,
) void {
    _ = b; // May be used for custom build steps in the future
    _ = optimize; // May be used in future platform-specific logic

    switch (target.result.os.tag) {
        .macos => {
            // Add all macOS frameworks to the module
            module.linkFramework("Foundation", .{});
            module.linkFramework("AppKit", .{});
            module.linkFramework("QuartzCore", .{});
            module.linkFramework("CoreGraphics", .{});

            switch (renderer) {
                .metal => {
                    module.linkFramework("Metal", .{});
                    module.linkFramework("MetalKit", .{});
                },
                .opengl => {
                    module.linkFramework("OpenGL", .{});
                },
                .vulkan => {
                    module.linkSystemLibrary("vulkan", .{});
                    module.linkSystemLibrary("MoltenVK", .{});
                },
                .cpu => {},
            }

            // Add Swift library paths
            const sys_path = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.sdk/usr/lib/swift/";
            const other_sys_path = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx";
            module.addLibraryPath(.{ .cwd_relative = sys_path });
            module.addLibraryPath(.{ .cwd_relative = other_sys_path });

            // Link all Swift runtime libraries
            module.linkSystemLibrary("swiftObjectiveC", .{});
            module.linkSystemLibrary("swiftCore", .{});
            module.linkSystemLibrary("swiftAppKit", .{});
            module.linkSystemLibrary("swiftCoreFoundation", .{});
            module.linkSystemLibrary("swiftCompatibilityConcurrency", .{});
            module.linkSystemLibrary("swiftCompatibility50", .{});
            module.linkSystemLibrary("swiftCompatibility51", .{});
            module.linkSystemLibrary("swiftCompatibility56", .{});
            module.linkSystemLibrary("swiftCompatibilityDynamicReplacements", .{});
            module.linkSystemLibrary("swift_Concurrency", .{});
            module.linkSystemLibrary("swiftUniformTypeIdentifiers", .{});
            module.linkSystemLibrary("swift_StringProcessing", .{});
            module.linkSystemLibrary("swiftDispatch", .{});
            module.linkSystemLibrary("swiftCoreGraphics", .{});
            module.linkSystemLibrary("swiftMetal", .{});
            module.linkSystemLibrary("swiftMetalKit", .{});
            module.linkSystemLibrary("swiftModelIO", .{});
            module.linkSystemLibrary("swiftIOKit", .{});
            module.linkSystemLibrary("swiftXPC", .{});
            module.linkSystemLibrary("swiftDarwin", .{});
            module.linkSystemLibrary("swiftCoreImage", .{});
            module.linkSystemLibrary("swiftQuartzCore", .{});
            module.linkSystemLibrary("swiftOSLog", .{});
            module.linkSystemLibrary("swiftos", .{});
            module.linkSystemLibrary("swiftsimd", .{});
        },
        .linux => {
            module.link_libc = true;
            module.linkSystemLibrary("X11", .{});
            module.linkSystemLibrary("Xrandr", .{});
            module.linkSystemLibrary("Xi", .{});
            module.linkSystemLibrary("Xcursor", .{});

            switch (renderer) {
                .vulkan => module.linkSystemLibrary("vulkan", .{}),
                .opengl => module.linkSystemLibrary("GL", .{}),
                .metal => @panic("Metal is not available on Linux"),
                .cpu => {},
            }
        },
        .windows => {
            module.linkSystemLibrary("user32", .{});
            module.linkSystemLibrary("gdi32", .{});
            module.linkSystemLibrary("shell32", .{});
            module.linkSystemLibrary("kernel32", .{});

            switch (renderer) {
                .vulkan => module.linkSystemLibrary("vulkan-1", .{}),
                .opengl => module.linkSystemLibrary("opengl32", .{}),
                .metal => @panic("Metal is not available on Windows"),
                .cpu => {},
            }
        },
        else => @panic("Unsupported operating system"),
    }
}

pub fn defaultRendererForTarget(os_tag: std.Target.Os.Tag) RendererBackend {
    return switch (os_tag) {
        .macos => .metal,
        .windows => .vulkan,
        .linux => .vulkan,
        else => .opengl,
    };
}

/// Configure an executable with platform-specific build steps (Swift builds, metal shaders, etc.)
/// The module should already have configurePlatformModule called on it
pub fn configurePlatform(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    module: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    renderer: RendererBackend,
) void {
    _ = module;
    _ = renderer;

    switch (target.result.os.tag) {
        .macos => configureMacOSExecutable(b, exe, target, optimize),
        .linux => {}, // Linux doesn't need extra executable configuration
        .windows => {}, // Windows doesn't need extra executable configuration
        else => @panic("Unsupported operating system"),
    }
}

/// Configure macOS-specific executable build steps (Swift library, Metal shaders)
fn configureMacOSExecutable(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    const arch = switch (target.result.cpu.arch) {
        .aarch64 => "arm64",
        .x86_64 => "x86_64",
        else => @panic("Unsupported architecture for macOS"),
    };

    const config = if (optimize == .Debug) "debug" else "release";

    // Use absolute paths so this works when building as a dependency
    const package_path = b.path("src/platform/macos").getPath(b);
    const swift_scratch_rel = b.fmt("swift-build/{s}", .{config});
    const swift_scratch = b.cache_root.join(b.allocator, &.{swift_scratch_rel}) catch @panic("OOM");
    const shaders_air = b.cache_root.join(b.allocator, &.{"shaders.air"}) catch @panic("OOM");
    const metallib_path = b.cache_root.join(b.allocator, &.{"default.metallib"}) catch @panic("OOM");
    const shaders_metal = b.path("src/platform/macos/swift/shaders.metal").getPath(b);
    const swift_build_dir = b.path("src/platform/macos/.build").getPath(b);

    const swift_build = b.addSystemCommand(&.{
        "swift",          "build",
        "--package-path", package_path,
        "--scratch-path", swift_scratch,
        "-c",             config,
        "--arch",         arch,
    });

    const metal_compile = b.addSystemCommand(&.{
        "xcrun", "-sdk",        "macosx", "metal",
        "-c",    shaders_metal, "-o",     shaders_air,
    });
    metal_compile.step.dependOn(&swift_build.step);

    const metal_lib = b.addSystemCommand(&.{
        "xcrun",     "-sdk", "macosx",      "metallib",
        shaders_air, "-o",   metallib_path,
    });
    metal_lib.step.dependOn(&metal_compile.step);

    const install_metallib = b.addInstallFile(.{ .cwd_relative = metallib_path }, "bin/default.metallib");
    install_metallib.step.dependOn(&metal_lib.step);

    const swift_clean = b.addSystemCommand(&.{ "rm", "-rf", swift_build_dir });

    const lib_src = b.fmt("{s}/arm64-apple-macosx/{s}/libMacPlatform.a", .{ swift_scratch, config });
    const lib_dest = "lib/libMacPlatform.a";

    const install_lib = b.addInstallFile(.{ .cwd_relative = lib_src }, lib_dest);
    install_lib.step.dependOn(&swift_build.step);

    // Link c++ for Swift interop
    exe.linkSystemLibrary("c++");

    // Link the Swift platform library
    exe.addObjectFile(.{ .cwd_relative = lib_src });

    // Make executable depend on these build steps
    exe.step.dependOn(&swift_build.step);
    exe.step.dependOn(&swift_clean.step);
    exe.step.dependOn(&install_lib.step);
    exe.step.dependOn(&install_metallib.step);
}
