const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Get the engine dependency (parent directory)
    const engine_dep = b.dependency("game-engine", .{
        .target = target,
        .optimize = optimize,
    });

    // Get the engine library artifact
    const engine_lib = engine_dep.artifact("game-engine");

    // Create the test game module
    const test_game_module = b.addModule("test_game", .{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Import the engine module
    test_game_module.addImport("engine", engine_dep.module("engine"));

    // Create the executable
    const exe = b.addExecutable(.{
        .name = "test-game",
        .root_module = test_game_module,
    });

    // Link the engine library (this brings in all dependencies and linking)
    exe.linkLibrary(engine_lib);

    // Install assets directory
    const install_assets = b.addInstallDirectory(.{
        .source_dir = b.path("assets"),
        .install_dir = .bin,
        .install_subdir = "assets",
    });
    exe.step.dependOn(&install_assets.step);

    // Install the Metal shader library (needed for Metal renderer)
    // The metallib is built by the engine dependency and available in its install prefix
    const metallib_path = b.pathJoin(&.{
        engine_dep.builder.install_prefix,
        "bin",
        "default.metallib",
    });
    const install_metallib = b.addInstallFile(.{ .cwd_relative = metallib_path }, "bin/default.metallib");
    // Make sure the engine library is fully built before trying to copy the metallib
    install_metallib.step.dependOn(&engine_lib.step);
    exe.step.dependOn(&install_metallib.step);

    b.installArtifact(exe);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the test game");
    run_step.dependOn(&run_cmd.step);
}
