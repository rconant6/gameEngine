const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Get the engine dependency (parent directory)
    const engine_dep = b.dependency("game-engine", .{
        .target = target,
        .optimize = optimize,
    });

    // Get the engine module
    const engine_module = engine_dep.module("engine");

    // Create the executable
    const exe = b.addExecutable(.{
        .name = "test-game",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add the engine module
    exe.root_module.addImport("engine", engine_module);

    // Install assets directory
    const install_assets = b.addInstallDirectory(.{
        .source_dir = b.path("assets"),
        .install_dir = .bin,
        .install_subdir = "assets",
    });
    exe.step.dependOn(&install_assets.step);

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
