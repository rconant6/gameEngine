const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Library module
    const lib_module = b.createModule(.{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Lexer tests
    const lexer_test_module = b.createModule(.{
        .root_source_file = b.path("tests/lexer_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    lexer_test_module.addImport("lib", lib_module);
    const lexer_tests = b.addTest(.{
        .root_module = lexer_test_module,
    });
    const run_lexer_tests = b.addRunArtifact(lexer_tests);
    const test_lexer_step = b.step("test-lexer", "Run lexer tests");
    test_lexer_step.dependOn(&run_lexer_tests.step);

    // Parser tests
    const parser_test_module = b.createModule(.{
        .root_source_file = b.path("tests/parser_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    parser_test_module.addImport("lib", lib_module);
    const parser_tests = b.addTest(.{
        .root_module = parser_test_module,
    });
    const run_parser_tests = b.addRunArtifact(parser_tests);
    const test_parser_step = b.step("test-parser", "Run parser tests");
    test_parser_step.dependOn(&run_lexer_tests.step);
    test_parser_step.dependOn(&run_parser_tests.step);

    // Combined test step
    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_lexer_tests.step);
    test_step.dependOn(&run_parser_tests.step);

    // Executable for live demo
    const exe_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const exe = b.addExecutable(.{
        .name = "scene-format-demo",
        .root_module = exe_module,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the scene format parser demo");
    run_step.dependOn(&run_cmd.step);
}
