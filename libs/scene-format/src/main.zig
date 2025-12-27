const std = @import("std");
const lex = @import("lexer.zig");
pub const Lexer = lex.Lexer;
const tok = @import("token.zig");
pub const Token = tok.Token;
pub const TokenTag = Token.Tag;
const ast = @import("ast.zig");
const parse = @import("parser.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const gpa_allocator = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(gpa_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // ===== Test parseNumber =====
    std.debug.print("\n=== PARSER DEMO - parseNumber ===\n\n", .{});
    {
        const number_tests = [_]struct { src: [:0]const u8, expected: f64 }{
            .{ .src = "42", .expected = 42.0 },
            .{ .src = "-42", .expected = -42.0 },
            .{ .src = "3.14", .expected = 3.14 },
            .{ .src = "-3.14", .expected = -3.14 },
            .{ .src = "0.0", .expected = 0.0 },
        };

        var passed: usize = 0;
        for (number_tests) |tc| {
            var parser = parse.Parser.init(allocator, tc.src, "test.scene") catch continue;
            const result = parser.parseNumber() catch continue;
            if (result == tc.expected) {
                std.debug.print("  ✓ '{s}' = {d}\n", .{ tc.src, result });
                passed += 1;
            }
        }
        std.debug.print("parseNumber: {d}/{d} passed\n", .{ passed, number_tests.len });
    }

    // ===== Test parseVectorValue =====
    std.debug.print("\n=== PARSER DEMO - parseVectorValue ===\n\n", .{});
    {
        const vector_tests = [_]struct { src: [:0]const u8, arity: u8, expected_len: usize }{
            .{ .src = "{1.0, 2.0}", .arity = 2, .expected_len = 2 },
            .{ .src = "{-1.0, -2.0}", .arity = 2, .expected_len = 2 },
            .{ .src = "{1.0, 2.0, 3.0}", .arity = 3, .expected_len = 3 },
            .{ .src = "{-1.0, -2.0, -3.0}", .arity = 3, .expected_len = 3 },
        };

        var passed: usize = 0;
        for (vector_tests) |tc| {
            var parser = parse.Parser.init(allocator, tc.src, "test.scene") catch continue;
            const result = parser.parseVectorValue(tc.arity) catch continue;
            if (result == .vector and result.vector.len == tc.expected_len) {
                std.debug.print("  ✓ vec{d}: '{s}'\n", .{ tc.arity, tc.src });
                passed += 1;
            }
        }
        std.debug.print("parseVectorValue: {d}/{d} passed\n", .{ passed, vector_tests.len });
    }

    // ===== Test parseSingleValue =====
    std.debug.print("\n=== PARSER DEMO - parseSingleValue ===\n\n", .{});
    {
        const BaseType = @import("ast.zig").BaseType;

        const single_tests = [_]struct { src: [:0]const u8, base_type: BaseType }{
            .{ .src = "42.5", .base_type = .f32 },
            .{ .src = "{1.0, 2.0}", .base_type = .vec2 },
            .{ .src = "{1.0, 2.0, 3.0}", .base_type = .vec3 },
            .{ .src = "true", .base_type = .bool },
            .{ .src = "false", .base_type = .bool },
            .{ .src = "\"hello world\"", .base_type = .string },
            .{ .src = "#FF00FF", .base_type = .color },
            .{ .src = "MyAsset", .base_type = .asset },
        };

        var passed: usize = 0;
        for (single_tests) |tc| {
            var parser = parse.Parser.init(allocator, tc.src, "test.scene") catch continue;
            _ = parser.parseSingleValue(tc.base_type) catch continue;
            std.debug.print("  ✓ {s}: '{s}'\n", .{ @tagName(tc.base_type), tc.src });
            passed += 1;
        }
        std.debug.print("parseSingleValue: {d}/{d} passed\n", .{ passed, single_tests.len });
    }

    // ===== Test parseArrayValue =====
    std.debug.print("\n=== PARSER DEMO - parseArrayValue ===\n\n", .{});
    {
        const BaseType = @import("ast.zig").BaseType;

        const array_tests = [_]struct { src: [:0]const u8, element_type: BaseType }{
            .{ .src = "{1.0, 2.0, 3.0}", .element_type = .f32 },
            .{ .src = "{true, false, true}", .element_type = .bool },
            .{ .src = "{{1.0, 2.0}, {3.0, 4.0}}", .element_type = .vec2 },
            .{ .src = "{\"hello\", \"world\"}", .element_type = .string },
        };

        var passed: usize = 0;
        for (array_tests) |tc| {
            var parser = parse.Parser.init(allocator, tc.src, "test.scene") catch continue;
            _ = parser.parseArrayValue(tc.element_type) catch continue;
            std.debug.print("  ✓ {s}[]: '{s}'\n", .{ @tagName(tc.element_type), tc.src });
            passed += 1;
        }
        std.debug.print("parseArrayValue: {d}/{d} passed\n", .{ passed, array_tests.len });
    }

    // ===== Test parseValue =====
    std.debug.print("\n=== PARSER DEMO - parseValue ===\n\n", .{});
    {
        const value_tests = [_]struct { src: [:0]const u8, type_annotation: ast.TypeAnnotation }{
            // Single values
            .{ .src = "42.5", .type_annotation = .{ .base_type = .f32, .is_array = false } },
            .{ .src = "{1.0, 2.0}", .type_annotation = .{ .base_type = .vec2, .is_array = false } },
            .{ .src = "true", .type_annotation = .{ .base_type = .bool, .is_array = false } },
            .{ .src = "\"hello\"", .type_annotation = .{ .base_type = .string, .is_array = false } },
            .{ .src = "#FF00FF", .type_annotation = .{ .base_type = .color, .is_array = false } },
            .{ .src = "MyAsset", .type_annotation = .{ .base_type = .asset, .is_array = false } },

            // Array values
            .{ .src = "{1.0, 2.0, 3.0}", .type_annotation = .{ .base_type = .f32, .is_array = true } },
            .{ .src = "{true, false}", .type_annotation = .{ .base_type = .bool, .is_array = true } },
            .{ .src = "{{1.0, 2.0}, {3.0, 4.0}}", .type_annotation = .{ .base_type = .vec2, .is_array = true } },
            .{ .src = "{\"a\", \"b\"}", .type_annotation = .{ .base_type = .string, .is_array = true } },
        };

        var passed: usize = 0;
        for (value_tests) |tc| {
            var parser = parse.Parser.init(allocator, tc.src, "test.scene") catch continue;
            _ = parser.parseValue(tc.type_annotation) catch continue;
            const array_marker = if (tc.type_annotation.is_array) "[]" else "";
            std.debug.print("  ✓ {s}{s}: '{s}'\n", .{ @tagName(tc.type_annotation.base_type), array_marker, tc.src });
            passed += 1;
        }
        std.debug.print("parseValue: {d}/{d} passed\n", .{ passed, value_tests.len });
    }

    // ===== Test parseTypeAnnotation =====
    std.debug.print("\n=== PARSER DEMO - parseTypeAnnotation ===\n\n", .{});
    {
        const BaseType = @import("ast.zig").BaseType;

        const type_tests = [_]struct { src: [:0]const u8, expected_base: BaseType, expected_array: bool }{
            // Base types
            .{ .src = "f32", .expected_base = .f32, .expected_array = false },
            .{ .src = "i32", .expected_base = .i32, .expected_array = false },
            .{ .src = "u32", .expected_base = .u32, .expected_array = false },
            .{ .src = "bool", .expected_base = .bool, .expected_array = false },
            .{ .src = "string", .expected_base = .string, .expected_array = false },
            .{ .src = "color", .expected_base = .color, .expected_array = false },
            .{ .src = "vec2", .expected_base = .vec2, .expected_array = false },
            .{ .src = "vec3", .expected_base = .vec3, .expected_array = false },
            .{ .src = "asset_ref", .expected_base = .asset, .expected_array = false },

            // Array types
            .{ .src = "f32[]", .expected_base = .f32, .expected_array = true },
            .{ .src = "bool[]", .expected_base = .bool, .expected_array = true },
            .{ .src = "string[]", .expected_base = .string, .expected_array = true },
            .{ .src = "vec2[]", .expected_base = .vec2, .expected_array = true },
        };

        var passed: usize = 0;
        for (type_tests) |tc| {
            var parser = parse.Parser.init(allocator, tc.src, "test.scene") catch continue;
            const type_ann = parser.parseTypeAnnotation() catch continue;
            if (type_ann.base_type == tc.expected_base and type_ann.is_array == tc.expected_array) {
                std.debug.print("  ✓ '{s}'\n", .{tc.src});
                passed += 1;
            }
        }
        std.debug.print("parseTypeAnnotation: {d}/{d} passed\n", .{ passed, type_tests.len });
    }

    // ===== Test parseProperty =====
    std.debug.print("\n=== PARSER DEMO - parseProperty ===\n\n", .{});
    {
        const property_tests = [_][:0]const u8{
            "rotation:f32 0.0",
            "position:vec2 {10.0, 20.0}",
            "scale:vec3 {1.0, 1.0, 1.0}",
            "visible:bool true",
            "name:string \"Player\"",
            "tint:color #FF00FF",
            "texture:asset_ref MyTexture",
            "values:f32[] {1.0, 2.0, 3.0}",
            "items:string[] {\"a\", \"b\", \"c\"}",
            "flags:bool[] {true, false, true}",
        };

        var passed: usize = 0;
        for (property_tests) |src| {
            var parser = parse.Parser.init(allocator, src, "test.scene") catch continue;
            _ = parser.parseProperty() catch continue;
            std.debug.print("  ✓ '{s}'\n", .{src});
            passed += 1;
        }
        std.debug.print("parseProperty: {d}/{d} passed\n", .{ passed, property_tests.len });
    }

    // ===== Test parseDeclaration (Top-Level Entry Point) =====
    std.debug.print("\n=== PARSER DEMO - parseDeclaration ===\n\n", .{});
    {
        const decl_tests = [_]struct { src: [:0]const u8, desc: []const u8 }{
            .{ .src = "[Circle:shape]", .desc = "shape" },
            .{ .src = "[MyFont:asset font]", .desc = "asset" },
            .{ .src = "[Player:entity]", .desc = "entity" },
            .{ .src = "[MainScene:scene]", .desc = "scene" },
        };

        var passed: usize = 0;
        for (decl_tests) |tc| {
            var parser = parse.Parser.init(allocator, tc.src, "test.scene") catch continue;
            _ = parser.parseDeclaration() catch continue;
            std.debug.print("  ✓ {s}: '{s}'\n", .{ tc.desc, tc.src });
            passed += 1;
        }
        std.debug.print("parseDeclaration: {d}/{d} passed\n", .{ passed, decl_tests.len });
    }

    std.debug.print("\n=== ALL TESTS COMPLETE ===\n", .{});
}

fn lexeme(token: Token, src: [:0]const u8) []const u8 {
    const start = token.loc.start;
    const end = token.loc.end;
    return src[start..end];
}
