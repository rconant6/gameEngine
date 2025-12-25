const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });

    const main_module = b.addModule("main", .{
        .root_source_file = b.path("src/scene-format.zig"),
        .target = target,
        .optimize = optimize,
    });

    const scene_lib = b.addLibrary(.{
        .name = "scene",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/scene-format.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(scene_lib);

    const exe = b.addExecutable(.{
        .name = "game-engine",
        .root_module = main_module,
    });

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the engine");
    run_step.dependOn(&run_cmd.step);

    // Lexer module
    const lexer_module = b.addModule("lexer", .{
        .root_source_file = b.path("src/lexer.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Lexer tests
    const lexer_test_module = b.createModule(.{
        .root_source_file = b.path("tests/lexer_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    lexer_test_module.addImport("lexer", lexer_module);

    const lexer_tests = b.addTest(.{
        .root_module = lexer_test_module,
    });

    const run_lexer_tests = b.addRunArtifact(lexer_tests);
    const test_lexer_step = b.step("test-lexer", "Run lexer tests");
    test_lexer_step.dependOn(&run_lexer_tests.step);
}
