const std = @import("std");

// Standalone build for the scene-format module — lets you iterate on the
// tokenizer / lexer / parser in isolation, without the whole engine.
//
//   cd src/scene-format
//   zig build test          # run every test block in the files listed below
//
// Add a file to `test_files` as you build it. Files with engine deps
// (parser.zig / writer.zig import "debug") stay commented until wired.

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Files whose `test { ... }` blocks should run. Pure-std only for now.
    const test_files = [_][]const u8{
        "token.zig",
        "lexer.zig",
        "ast.zig",
        "parser.zig",
        "schema.zig",
        "graph.zig",
        "ingest_test.zig",
    };

    const test_step = b.step("test", "Run scene-format unit tests");

    for (test_files) |file| {
        const t = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(file),
                .target = target,
                .optimize = optimize,
            }),
        });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }
}
