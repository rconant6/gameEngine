const std = @import("std");
const root = @import("../build.zig");

const M = root.M;
const Modules = root.Modules;

const Import = struct { []const u8, *std.Build.Module };
const AnonImport = struct { []const u8, []const u8 };
const TestSpec = struct {
    name: []const u8,
    path: []const u8,
    imports: []const Import = &.{},
    anon_imports: []const AnonImport = &.{},
    link_engine: bool = false,
};

fn mod(modules: *const Modules, id: M) *std.Build.Module {
    return modules[@intFromEnum(id)];
}

/// Register all test suites on the given step.
pub fn addAllTests(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    modules: *const Modules,
    engine_lib: *std.Build.Step.Compile,
    test_step: *std.Build.Step,
    platform_step: ?*std.Build.Step,
) void {
    // ========================================
    // Layer 1: Core
    // ========================================
    const core_tests = [_]TestSpec{
        .{ .name = "v2-tests", .path = "tests/core/test_v2.zig", .anon_imports = &.{
            .{ "V2", "src/math/V2.zig" },
        } },
        .{ .name = "color-tests", .path = "tests/renderer/test_color.zig", .imports = &.{
            .{ "math", mod(modules, .math) },
        }, .anon_imports = &.{
            .{ "color", "src/renderer/color.zig" },
        } },
    };

    // ========================================
    // Layer 2: ECS
    // ========================================
    const ecs_tests = [_]TestSpec{
        .{ .name = "ecs-tests", .path = "tests/ecs/test_component_storage.zig", .imports = &.{
            .{ "math", mod(modules, .math) },
        }, .anon_imports = &.{
            .{ "ComponentStorage", "src/ecs/ComponentStorage.zig" },
        } },
        .{ .name = "tag-tests", .path = "tests/ecs/test_tag.zig", .anon_imports = &.{
            .{ "Tag", "src/ecs/Tag.zig" },
        } },
        .{ .name = "query-tests", .path = "tests/ecs/test_query.zig", .imports = &.{
            .{ "math", mod(modules, .math) },
            .{ "ecs", mod(modules, .ecs) },
        }, .link_engine = true },
        .{ .name = "world-tests", .path = "tests/ecs/test_world.zig", .imports = &.{
            .{ "math", mod(modules, .math) },
            .{ "scene", mod(modules, .scene) },
            .{ "ecs", mod(modules, .ecs) },
        }, .link_engine = true },
        .{ .name = "world-query-tests", .path = "tests/ecs/test_world_queries.zig", .imports = &.{
            .{ "math", mod(modules, .math) },
            .{ "scene", mod(modules, .scene) },
            .{ "ecs", mod(modules, .ecs) },
        }, .link_engine = true },
        .{ .name = "collider-tests", .path = "tests/ecs/test_collider.zig", .imports = &.{
            .{ "math", mod(modules, .math) },
            .{ "ecs", mod(modules, .ecs) },
        }, .link_engine = true },
    };

    // ========================================
    // Layer 2B: Action system
    // ========================================
    const action_tests = [_]TestSpec{
        .{ .name = "action-tests", .path = "tests/ecs/test_action.zig", .imports = &.{
            .{ "math", mod(modules, .math) },
            .{ "Action", mod(modules, .action) },
        }, .link_engine = true },
        .{ .name = "action-bindings-tests", .path = "tests/ecs/test_action_bindings.zig", .imports = &.{
            .{ "math", mod(modules, .math) },
            .{ "Action", mod(modules, .action) },
        }, .link_engine = true },
        .{ .name = "collision-trigger-tests", .path = "tests/ecs/test_collision_trigger.zig", .imports = &.{
            .{ "math", mod(modules, .math) },
            .{ "Action", mod(modules, .action) },
        }, .link_engine = true },
        .{ .name = "input-trigger-tests", .path = "tests/ecs/test_input_trigger.zig", .imports = &.{
            .{ "math", mod(modules, .math) },
            .{ "Action", mod(modules, .action) },
            .{ "platform", mod(modules, .platform) },
        }, .link_engine = true },
        .{ .name = "time-trigger-tests", .path = "tests/ecs/test_time_trigger.zig", .imports = &.{
            .{ "math", mod(modules, .math) },
            .{ "Action", mod(modules, .action) },
            .{ "ecs", mod(modules, .ecs) },
        }, .link_engine = true },
    };

    // ========================================
    // Layer 3: Collision Detection
    // ========================================
    const collision_tests = [_]TestSpec{
        .{ .name = "collision-tests", .path = "tests/collision/test_collision_detection.zig", .imports = &.{
            .{ "math", mod(modules, .math) },
            .{ "ecs", mod(modules, .ecs) },
            .{ "systems", mod(modules, .systems) },
        }, .link_engine = true },
    };

    // ========================================
    // Layer 4: Scene Format
    // ========================================
    const scene_tests = [_]TestSpec{
        .{ .name = "scene-lexer-tests", .path = "tests/scene-format/lexer_test.zig", .imports = &.{
            .{ "scene-format", mod(modules, .scene_format) },
        } },
        .{ .name = "scene-parser-tests", .path = "tests/scene-format/parser_test.zig", .imports = &.{
            .{ "scene-format", mod(modules, .scene_format) },
        } },
        .{ .name = "template-parser-tests", .path = "tests/scene-format/template_parser_test.zig", .imports = &.{
            .{ "scene-format", mod(modules, .scene_format) },
        } },
        .{ .name = "nested-block-parser-tests", .path = "tests/scene-format/parser_nested_blocks_test.zig", .imports = &.{
            .{ "scene-format", mod(modules, .scene_format) },
        } },
        .{ .name = "scene-tests", .path = "tests/scene/test_scene_integration.zig", .imports = &.{
            .{ "scene-format", mod(modules, .scene_format) },
        } },
        .{ .name = "template-instantiation-tests", .path = "tests/scene/test_template_instantiation.zig", .imports = &.{
            .{ "scene-format", mod(modules, .scene_format) },
            .{ "ecs", mod(modules, .ecs) },
            .{ "scene", mod(modules, .scene) },
            .{ "assets", mod(modules, .assets) },
            .{ "math", mod(modules, .math) },
        }, .link_engine = true },
    };

    // ========================================
    // Layer 4B: UI
    // ========================================
    const ui_tests = [_]TestSpec{
        .{ .name = "ui-tests", .path = "tests/ui/test_layout.zig", .imports = &.{
            .{ "math", mod(modules, .math) },
            .{ "ui", mod(modules, .ui) },
        } },
    };

    // ========================================
    // Layer 4C: Renderer
    // ========================================
    const renderer_tests = [_]TestSpec{
        .{ .name = "shapes-tests", .path = "tests/renderer/test_shapes.zig", .imports = &.{
            .{ "math", mod(modules, .math) },
            .{ "renderer", mod(modules, .renderer) },
        }, .link_engine = true },
    };

    // ========================================
    // Layer 4D: ZXL
    // ========================================
    const zxl_tests = [_]TestSpec{
        .{ .name = "zxl-image-tests", .path = "tests/zxl/test_zxl_image.zig", .imports = &.{
            .{ "zxl", mod(modules, .zxl) },
            .{ "math", mod(modules, .math) },
        } },
        .{ .name = "zxl-reader-tests", .path = "tests/zxl/test_zxl_reader.zig", .imports = &.{
            .{ "zxl", mod(modules, .zxl) },
            .{ "math", mod(modules, .math) },
        } },
    };

    // ========================================
    // Layer 5: Integration
    // ========================================
    const integration_tests = [_]TestSpec{
        .{ .name = "integration-tests", .path = "tests/integration/test_end_to_end.zig", .imports = &.{
            .{ "math", mod(modules, .math) },
            .{ "ecs", mod(modules, .ecs) },
            .{ "systems", mod(modules, .systems) },
        }, .link_engine = true },
    };

    // Register all layers
    const all_layers = .{
        &core_tests,
        &ecs_tests,
        &action_tests,
        &collision_tests,
        &scene_tests,
        &ui_tests,
        &renderer_tests,
        &zxl_tests,
        &integration_tests,
    };

    inline for (all_layers) |layer| {
        for (layer) |spec| {
            addTest(b, target, optimize, engine_lib, test_step, platform_step, spec);
        }
    }
}

fn addTest(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    engine_lib: *std.Build.Step.Compile,
    test_step: *std.Build.Step,
    platform_step: ?*std.Build.Step,
    spec: TestSpec,
) void {
    const test_mod = b.addModule(spec.name, .{
        .root_source_file = b.path(spec.path),
        .target = target,
        .optimize = optimize,
    });

    for (spec.imports) |entry| {
        test_mod.addImport(entry[0], entry[1]);
    }

    for (spec.anon_imports) |entry| {
        const anon = b.createModule(.{
            .root_source_file = b.path(entry[1]),
        });
        for (spec.imports) |imp| {
            anon.addImport(imp[0], imp[1]);
        }
        test_mod.addImport(entry[0], anon);
    }

    const t = b.addTest(.{
        .name = spec.name,
        .root_module = test_mod,
    });

    if (spec.link_engine) {
        t.linkLibrary(engine_lib);
    }

    // Ensure platform libraries (e.g. Swift on macOS) are built before tests,
    // since modules transitively pull in platform linking requirements.
    if (platform_step) |step| {
        t.step.dependOn(step);
    }

    test_step.dependOn(&b.addRunArtifact(t).step);
}
