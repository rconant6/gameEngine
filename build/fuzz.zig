// build/fuzz.zig — registers opt-in fuzz steps in the build graph.
//
// Each fuzzer gets its own named step so you can run them independently:
//
//   zig build fuzz-lexer  --fuzz     # hunt bugs in the lexer
//   zig build fuzz-parser --fuzz     # hunt bugs in the parser
//   zig build fuzz-font   --fuzz     # hunt bugs in font binary parsing
//   zig build fuzz-math   --fuzz     # verify math invariants
//
// None of these run as part of `zig build test` — they are opt-in only.
// The fuzzer writes a corpus to .zig-cache/fuzz/ and persists it across runs.
// Any crash-reproducing input is saved there; commit it as a regression test.
//
// IMPORTANT: fuzz modules are created as fresh isolated instances (not the
// shared module objects from the main build) to avoid a Zig 0.16.0 bug where
// transitive Swift/platform linking in fuzz mode causes builtin.StackTrace to
// be duplicated and mismatch debug.StackTrace in the test runner.

const std = @import("std");

pub fn addFuzzSteps(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    // Stub debug module — no-op log, no platform/Swift deps.
    const debug_stub = b.createModule(.{
        .root_source_file = b.path("tests/fuzz/debug_stub.zig"),
        .target = target,
        .optimize = optimize,
    });

    // scene-format: needs debug injected (parser.zig uses log.err)
    const scene_format_mod = b.createModule(.{
        .root_source_file = b.path("src/scene-format/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    scene_format_mod.addImport("debug", debug_stub);

    // math: no deps
    const math_mod = b.createModule(.{
        .root_source_file = b.path("src/math/math.zig"),
        .target = target,
        .optimize = optimize,
    });

    // FontReader: no deps (pure data parsing, no platform)
    const font_reader_mod = b.createModule(.{
        .root_source_file = b.path("src/assets/font/FontReader.zig"),
        .target = target,
        .optimize = optimize,
    });

    addFuzzer(b, target, optimize, .{
        .step_name = "fuzz-lexer",
        .description = "Fuzz the scene-format Lexer",
        .test_path = "tests/fuzz/fuzz_lexer.zig",
        .named_modules = &.{
            .{ "scene-format", scene_format_mod },
        },
    });

    addFuzzer(b, target, optimize, .{
        .step_name = "fuzz-parser",
        .description = "Fuzz the scene-format Parser (end-to-end)",
        .test_path = "tests/fuzz/fuzz_parser.zig",
        .named_modules = &.{
            .{ "scene-format", scene_format_mod },
        },
    });

    addFuzzer(b, target, optimize, .{
        .step_name = "fuzz-font",
        .description = "Fuzz the font binary reader / TTF parser",
        .test_path = "tests/fuzz/fuzz_font.zig",
        .named_modules = &.{
            .{ "FontReader", font_reader_mod },
        },
    });

    addFuzzer(b, target, optimize, .{
        .step_name = "fuzz-math",
        .description = "Property-fuzz V2 / V2I / V2U / ScreenPoint invariants",
        .test_path = "tests/fuzz/fuzz_math.zig",
        .named_modules = &.{
            .{ "math", math_mod },
        },
    });
}

const NamedModule = struct { []const u8, *std.Build.Module };

const FuzzSpec = struct {
    step_name: []const u8,
    description: []const u8,
    test_path: []const u8,
    named_modules: []const NamedModule = &.{},
};

fn addFuzzer(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    spec: FuzzSpec,
) void {
    const fuzz_mod = b.createModule(.{
        .root_source_file = b.path(spec.test_path),
        .target = target,
        .optimize = optimize,
    });

    for (spec.named_modules) |entry| {
        fuzz_mod.addImport(entry[0], entry[1]);
    }

    const fuzz_test = b.addTest(.{
        .name = spec.step_name,
        .root_module = fuzz_mod,
    });

    const run = b.addRunArtifact(fuzz_test);
    b.step(spec.step_name, spec.description).dependOn(&run.step);
}
