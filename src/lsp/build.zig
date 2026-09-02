const std = @import("std");

// Standalone build for the scene-lsp module — lets you iterate on the
// language server (transport, rpc, and the rest of the PURE-LSP substrate)
// in isolation, without the whole engine.
//
//   cd src/lsp
//   zig build test          # run every test block in the files listed below
//   zig build run           # run the server over stdio (once main.zig exists)
//
// Two test tiers:
//   - std_only_tests : pure-LSP substrate, no engine dependency (transport, rpc)
//   - scene_fmt_tests: files that legitimately need scene-format types
//                      (LineIndex/types use Loc + Diagnostic). Given the
//                      `scene_fmt` module below. NOT the parked adapter —
//                      diagnostics.zig stays out until the DSL grammar lands.

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // The scene-format library as an importable module, name = "scene_fmt"
    const scene_fmt = b.createModule(.{
        .root_source_file = b.path("../scene-format/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run scene-lsp unit tests");

    // ------------------------------------------------------------------
    // Tier 1 — std-only. No scene-format import.
    // ------------------------------------------------------------------
    const std_only_tests = [_][]const u8{
        "Transport.zig",
        "rpc.zig",
    };
    for (std_only_tests) |file| {
        const t = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(file),
                .target = target,
                .optimize = optimize,
            }),
        });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    // ------------------------------------------------------------------
    // Tier 2 — need scene_fmt (Loc / Diagnostic).
    // ------------------------------------------------------------------
    const scene_fmt_tests = [_][]const u8{
        "types.zig",
        "LineIndex.zig",
        "diagnostics.zig",
        "doc_store.zig",
    };
    for (scene_fmt_tests) |file| {
        const mod = b.createModule(.{
            .root_source_file = b.path(file),
            .target = target,
            .optimize = optimize,
        });
        mod.addImport("scene_fmt", scene_fmt);
        const t = b.addTest(.{ .root_module = mod });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    // ------------------------------------------------------------------
    // run step — the server binary over stdio. Commented until main.zig
    // exists; uncomment (and add "main.zig") once the loop is wired.
    // ------------------------------------------------------------------
    // const exe = b.addExecutable(.{
    //     .name = "scene-lsp",
    //     .root_module = b.createModule(.{
    //         .root_source_file = b.path("main.zig"),
    //         .target = target,
    //         .optimize = optimize,
    //     }),
    // });
    // exe.root_module.addImport("scene_fmt", scene_fmt);
    // b.installArtifact(exe);
    //
    // const run_cmd = b.addRunArtifact(exe);
    // run_cmd.step.dependOn(b.getInstallStep());
    // const run_step = b.step("run", "Run the scene-lsp server over stdio");
    // run_step.dependOn(&run_cmd.step);
}
