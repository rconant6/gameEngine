const std = @import("std");
const testing = std.testing;

const scene = @import("lib");
const Parser = scene.Parser;
const Lexer = scene.Lexer;
const SceneFile = scene.SceneFile;
const Value = scene.Value;
const Property = scene.Property;
const Declaration = scene.Declaration;

// Helper to create a parser from source and parse the whole file
fn parseSource(src: [:0]const u8) !SceneFile {
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    return try parser.parse();
}

// Helper to get an arena allocator for tests
fn testArena() std.heap.ArenaAllocator {
    return std.heap.ArenaAllocator.init(testing.allocator);
}

// Helper to free all allocations in a Value
fn freeValue(allocator: std.mem.Allocator, value: Value) void {
    switch (value) {
        .string => |s| allocator.free(s),
        .assetRef => |a| allocator.free(a),
        .vector => |v| allocator.free(v),
        .array => |arr| {
            for (arr) |elem| {
                freeValue(allocator, elem);
            }
            allocator.free(arr);
        },
        else => {},
    }
}

// Helper to free all allocations in a Property
fn freeProperty(allocator: std.mem.Allocator, prop: Property) void {
    allocator.free(prop.name);
    freeValue(allocator, prop.value);
}

// Helper to free all allocations in a Declaration
fn freeDeclaration(allocator: std.mem.Allocator, decl: Declaration) void {
    switch (decl) {
        .entity => |e| {
            allocator.free(e.name);
            for (e.components) |comp| {
                allocator.free(comp.name);
                for (comp.properties) |prop| {
                    freeProperty(allocator, prop);
                }
                allocator.free(comp.properties);
            }
            allocator.free(e.components);
        },
        .scene => |s| {
            allocator.free(s.name);
            for (s.decls) |nested_decl| {
                freeDeclaration(allocator, nested_decl);
            }
            allocator.free(s.decls);
        },
        .asset => |a| {
            allocator.free(a.name);
            for (a.properties) |prop| {
                freeProperty(allocator, prop);
            }
            allocator.free(a.properties);
        },
        .component => |c| {
            allocator.free(c.name);
            for (c.properties) |prop| {
                freeProperty(allocator, prop);
            }
            allocator.free(c.properties);
        },
        .shape => |sh| {
            allocator.free(sh.name);
            for (sh.properties) |prop| {
                freeProperty(allocator, prop);
            }
            allocator.free(sh.properties);
        },
    }
}

// Helper to free all allocations in a SceneFile
fn freeSceneFile(allocator: std.mem.Allocator, scene_file: SceneFile) void {
    for (scene_file.decls) |decl| {
        freeDeclaration(allocator, decl);
    }
    allocator.free(scene_file.decls);
    // Note: source_file_name is not allocated by parser, don't free it
}

// ============================================================================
// LOW-LEVEL PARSER FUNCTION TESTS
// ============================================================================

// Test parseNumber - positive integer
test "parser.parseNumber - positive integer" {
    const src = "42";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const num = try parser.parseNumber();
    try testing.expectEqual(@as(f64, 42.0), num);
}

// Test parseNumber - positive float
test "parser.parseNumber - positive float" {
    const src = "3.14";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const num = try parser.parseNumber();
    try testing.expectEqual(@as(f64, 3.14), num);
}

// Test parseNumber - negative integer
test "parser.parseNumber - negative integer" {
    const src = "-42";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const num = try parser.parseNumber();
    try testing.expectEqual(@as(f64, -42.0), num);
}
// Test parseNumber - negative float
test "parser.parseNumber - negative float" {
    const src = "-3.14";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const num = try parser.parseNumber();
    try testing.expectEqual(@as(f64, -3.14), num);
}

// Test parseNumber - zero
test "parser.parseNumber - zero" {
    const src = "0";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const num = try parser.parseNumber();
    try testing.expectEqual(@as(f64, 0.0), num);
}

// Test parseNumber - zero float
test "parser.parseNumber - zero float" {
    const src = "0.0";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const num = try parser.parseNumber();
    try testing.expectEqual(@as(f64, 0.0), num);
}

// Test parseNumber - negative zero
test "parser.parseNumber - negative zero" {
    const src = "-0.0";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const num = try parser.parseNumber();
    try testing.expectEqual(@as(f64, -0.0), num);
}

// Test parseNumber - large number
test "parser.parseNumber - large number" {
    const src = "123456.789";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const num = try parser.parseNumber();
    try testing.expectEqual(@as(f64, 123456.789), num);
}

// Test parseVectorValue - vec2 positive
test "parser.parseVectorValue - vec2 positive" {
    var arena = testArena();
    defer arena.deinit();
    const allocator = arena.allocator();

    const src = "{1.0, 2.0}";
    var parser = try Parser.init(allocator, src, "test.scene");
    const value = try parser.parseVectorValue(2);
    try testing.expect(value == .vector);
    try testing.expectEqual(@as(usize, 2), value.vector.len);
    try testing.expectEqual(@as(f64, 1.0), value.vector[0]);
    try testing.expectEqual(@as(f64, 2.0), value.vector[1]);
}

// Test parseVectorValue - vec2 negative
test "parser.parseVectorValue - vec2 negative" {
    const src = "{-10.5, -20.3}";
    var arena = testArena();
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = try Parser.init(allocator, src, "test.scene");
    const value = try parser.parseVectorValue(2);
    try testing.expect(value == .vector);
    try testing.expectEqual(@as(f64, -10.5), value.vector[0]);
    try testing.expectEqual(@as(f64, -20.3), value.vector[1]);
}

// Test parseVectorValue - vec2 mixed
test "parser.parseVectorValue - vec2 mixed" {
    const src = "{-5.0, 10.0}";
    var arena = testArena();
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = try Parser.init(allocator, src, "test.scene");
    const value = try parser.parseVectorValue(2);
    try testing.expectEqual(@as(f64, -5.0), value.vector[0]);
    try testing.expectEqual(@as(f64, 10.0), value.vector[1]);
}

// Test parseVectorValue - vec2 integers
test "parser.parseVectorValue - vec2 integers" {
    const src = "{10, 20}";
    var arena = testArena();
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = try Parser.init(allocator, src, "test.scene");
    const value = try parser.parseVectorValue(2);
    try testing.expectEqual(@as(f64, 10.0), value.vector[0]);
    try testing.expectEqual(@as(f64, 20.0), value.vector[1]);
}

// Test parseVectorValue - vec3 positive
test "parser.parseVectorValue - vec3 positive" {
    const src = "{1.0, 2.0, 3.0}";
    var arena = testArena();
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = try Parser.init(allocator, src, "test.scene");
    const value = try parser.parseVectorValue(3);
    try testing.expect(value == .vector);
    try testing.expectEqual(@as(usize, 3), value.vector.len);
    try testing.expectEqual(@as(f64, 1.0), value.vector[0]);
    try testing.expectEqual(@as(f64, 2.0), value.vector[1]);
    try testing.expectEqual(@as(f64, 3.0), value.vector[2]);
}

// Test parseVectorValue - vec3 negative
test "parser.parseVectorValue - vec3 negative" {
    const src = "{-1.0, -2.0, -3.0}";
    var arena = testArena();
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = try Parser.init(allocator, src, "test.scene");
    const value = try parser.parseVectorValue(3);
    try testing.expectEqual(@as(f64, -1.0), value.vector[0]);
    try testing.expectEqual(@as(f64, -2.0), value.vector[1]);
    try testing.expectEqual(@as(f64, -3.0), value.vector[2]);
}

// Test parseVectorValue - vec3 mixed
test "parser.parseVectorValue - vec3 mixed" {
    const src = "{-1.5, 0.0, 2.5}";
    var arena = testArena();
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = try Parser.init(allocator, src, "test.scene");
    const value = try parser.parseVectorValue(3);
    try testing.expectEqual(@as(f64, -1.5), value.vector[0]);
    try testing.expectEqual(@as(f64, 0.0), value.vector[1]);
    try testing.expectEqual(@as(f64, 2.5), value.vector[2]);
}

// Test parseVectorValue - vec2 with spaces
test "parser.parseVectorValue - vec2 with spaces" {
    const src = "{ 1.0 , 2.0 }";
    var arena = testArena();
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = try Parser.init(allocator, src, "test.scene");
    const value = try parser.parseVectorValue(2);
    try testing.expectEqual(@as(f64, 1.0), value.vector[0]);
    try testing.expectEqual(@as(f64, 2.0), value.vector[1]);
}

// Test parseSingleValue - f32
test "parser.parseSingleValue - f32" {
    const src = "42.5";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const value = try parser.parseSingleValue(.f32);
    try testing.expect(value == .number);
    try testing.expectEqual(@as(f64, 42.5), value.number);
}

// Test parseSingleValue - i32
test "parser.parseSingleValue - i32" {
    const src = "-42";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const value = try parser.parseSingleValue(.i32);
    try testing.expect(value == .number);
    try testing.expectEqual(@as(f64, -42.0), value.number);
}

// Test parseSingleValue - u32
test "parser.parseSingleValue - u32" {
    const src = "100";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const value = try parser.parseSingleValue(.u32);
    try testing.expect(value == .number);
    try testing.expectEqual(@as(f64, 100.0), value.number);
}

// Test parseSingleValue - bool true
test "parser.parseSingleValue - bool true" {
    const src = "true";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const value = try parser.parseSingleValue(.bool);
    try testing.expect(value == .boolean);
    try testing.expect(value.boolean);
}

// Test parseSingleValue - bool false
test "parser.parseSingleValue - bool false" {
    const src = "false";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const value = try parser.parseSingleValue(.bool);
    try testing.expect(value == .boolean);
    try testing.expect(!value.boolean);
}

// Test parseSingleValue - string
test "parser.parseSingleValue - string" {
    const src = "\"hello world\"";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const value = try parser.parseSingleValue(.string);
    defer testing.allocator.free(value.string);
    try testing.expect(value == .string);
    try testing.expectEqualStrings("hello world", value.string);
}

// Test parseSingleValue - string empty
test "parser.parseSingleValue - string empty" {
    const src = "\"\"";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const value = try parser.parseSingleValue(.string);
    defer testing.allocator.free(value.string);
    try testing.expect(value == .string);
    try testing.expectEqualStrings("", value.string);
}

// Test parseSingleValue - color 6 digit
test "parser.parseSingleValue - color 6 digit" {
    const src = "#FF6600";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const value = try parser.parseSingleValue(.color);
    try testing.expect(value == .color);
    try testing.expectEqual(@as(u32, 0xFF6600), value.color);
}

// Test parseSingleValue - color 8 digit
test "parser.parseSingleValue - color 8 digit" {
    const src = "#FF660080";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const value = try parser.parseSingleValue(.color);
    try testing.expect(value == .color);
    try testing.expectEqual(@as(u32, 0xFF660080), value.color);
}

// Test parseSingleValue - asset reference
test "parser.parseSingleValue - asset reference" {
    const src = "\"my_asset\"";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const value = try parser.parseSingleValue(.asset);
    defer testing.allocator.free(value.assetRef);
    try testing.expect(value == .assetRef);
    try testing.expectEqualStrings("my_asset", value.assetRef);
}

// Test parseSingleValue - vec2
test "parser.parseSingleValue - vec2" {
    const src = "{10.0, 20.0}";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const value = try parser.parseSingleValue(.vec2);
    defer testing.allocator.free(value.vector);
    try testing.expect(value == .vector);
    try testing.expectEqual(@as(usize, 2), value.vector.len);
    try testing.expectEqual(@as(f64, 10.0), value.vector[0]);
    try testing.expectEqual(@as(f64, 20.0), value.vector[1]);
}

// Test parseSingleValue - vec3
test "parser.parseSingleValue - vec3" {
    const src = "{1.0, 2.0, 3.0}";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const value = try parser.parseSingleValue(.vec3);
    defer testing.allocator.free(value.vector);
    try testing.expect(value == .vector);
    try testing.expectEqual(@as(usize, 3), value.vector.len);
}

// Test parseArrayValue - f32 array
test "parser.parseArrayValue - f32 array" {
    const src = "{1.0, 2.0, 3.0, 4.0}";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const value = try parser.parseArrayValue(.f32);
    defer testing.allocator.free(value.array);
    try testing.expect(value == .array);
    try testing.expectEqual(@as(usize, 4), value.array.len);
    try testing.expect(value.array[0] == .number);
    try testing.expectEqual(@as(f64, 1.0), value.array[0].number);
    try testing.expectEqual(@as(f64, 4.0), value.array[3].number);
}

// Test parseArrayValue - i32 array
test "parser.parseArrayValue - i32 array" {
    const src = "{-1, 0, 1, 2}";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const value = try parser.parseArrayValue(.i32);
    defer testing.allocator.free(value.array);
    try testing.expect(value == .array);
    try testing.expectEqual(@as(usize, 4), value.array.len);
    try testing.expectEqual(@as(f64, -1.0), value.array[0].number);
}

// Test parseArrayValue - bool array
test "parser.parseArrayValue - bool array" {
    const src = "{true, false, true}";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const value = try parser.parseArrayValue(.bool);
    defer testing.allocator.free(value.array);
    try testing.expect(value == .array);
    try testing.expectEqual(@as(usize, 3), value.array.len);
    try testing.expect(value.array[0].boolean);
    try testing.expect(!value.array[1].boolean);
    try testing.expect(value.array[2].boolean);
}

// Test parseArrayValue - string array
test "parser.parseArrayValue - string array" {
    const src = "{\"hello\", \"world\", \"test\"}";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const value = try parser.parseArrayValue(.string);
    defer {
        for (value.array) |elem| {
            testing.allocator.free(elem.string);
        }
        testing.allocator.free(value.array);
    }
    try testing.expect(value == .array);
    try testing.expectEqual(@as(usize, 3), value.array.len);
    try testing.expectEqualStrings("hello", value.array[0].string);
    try testing.expectEqualStrings("world", value.array[1].string);
    try testing.expectEqualStrings("test", value.array[2].string);
}

// Test parseArrayValue - color array
test "parser.parseArrayValue - color array" {
    const src = "{#FF0000, #00FF00, #0000FF}";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const value = try parser.parseArrayValue(.color);
    defer testing.allocator.free(value.array);
    try testing.expect(value == .array);
    try testing.expectEqual(@as(usize, 3), value.array.len);
    try testing.expectEqual(@as(u32, 0xFF0000), value.array[0].color);
    try testing.expectEqual(@as(u32, 0x00FF00), value.array[1].color);
    try testing.expectEqual(@as(u32, 0x0000FF), value.array[2].color);
}

// Test parseArrayValue - empty array
test "parser.parseArrayValue - empty array" {
    const src = "{}";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const value = try parser.parseArrayValue(.f32);
    defer testing.allocator.free(value.array);
    try testing.expect(value == .array);
    try testing.expectEqual(@as(usize, 0), value.array.len);
}

// Test parseArrayValue - single element
test "parser.parseArrayValue - single element" {
    const src = "{42.0}";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const value = try parser.parseArrayValue(.f32);
    defer testing.allocator.free(value.array);
    try testing.expect(value == .array);
    try testing.expectEqual(@as(usize, 1), value.array.len);
    try testing.expectEqual(@as(f64, 42.0), value.array[0].number);
}

// Test parseTypeAnnotation - base type
test "parser.parseTypeAnnotation - base type f32" {
    const src = "f32";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const type_ann = try parser.parseTypeAnnotation();
    try testing.expect(type_ann.base_type == .f32);
    try testing.expect(!type_ann.is_array);
}

// Test parseTypeAnnotation - array type
test "parser.parseTypeAnnotation - array type f32[]" {
    const src = "f32[]";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const type_ann = try parser.parseTypeAnnotation();
    try testing.expect(type_ann.base_type == .f32);
    try testing.expect(type_ann.is_array);
}

// Test parseTypeAnnotation - all base types
test "parser.parseTypeAnnotation - vec2" {
    const src = "vec2";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const type_ann = try parser.parseTypeAnnotation();
    try testing.expect(type_ann.base_type == .vec2);
    try testing.expect(!type_ann.is_array);
}

test "parser.parseTypeAnnotation - vec3" {
    const src = "vec3";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const type_ann = try parser.parseTypeAnnotation();
    try testing.expect(type_ann.base_type == .vec3);
}

test "parser.parseTypeAnnotation - i32" {
    const src = "i32";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const type_ann = try parser.parseTypeAnnotation();
    try testing.expect(type_ann.base_type == .i32);
}

test "parser.parseTypeAnnotation - u32" {
    const src = "u32";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const type_ann = try parser.parseTypeAnnotation();
    try testing.expect(type_ann.base_type == .u32);
}

test "parser.parseTypeAnnotation - bool" {
    const src = "bool";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const type_ann = try parser.parseTypeAnnotation();
    try testing.expect(type_ann.base_type == .bool);
}

test "parser.parseTypeAnnotation - string" {
    const src = "string";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const type_ann = try parser.parseTypeAnnotation();
    try testing.expect(type_ann.base_type == .string);
}

test "parser.parseTypeAnnotation - color" {
    const src = "color";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const type_ann = try parser.parseTypeAnnotation();
    try testing.expect(type_ann.base_type == .color);
}

test "parser.parseTypeAnnotation - asset_ref" {
    const src = "asset_ref";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const type_ann = try parser.parseTypeAnnotation();
    try testing.expect(type_ann.base_type == .asset);
}

// Test parseProperty - simple f32 property
test "parser.parseProperty - simple f32" {
    const src = "rotation:f32 0.0";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const prop = try parser.parseProperty();
    defer testing.allocator.free(prop.name);
    try testing.expectEqualStrings("rotation", prop.name);
    try testing.expect(prop.type_annotation.base_type == .f32);
    try testing.expect(!prop.type_annotation.is_array);
    try testing.expect(prop.value == .number);
    try testing.expectEqual(@as(f64, 0.0), prop.value.number);
}

// Test parseProperty - vec2 property
test "parser.parseProperty - vec2" {
    const src = "position:vec2 {10.0, 20.0}";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const prop = try parser.parseProperty();
    defer testing.allocator.free(prop.name);
    defer testing.allocator.free(prop.value.vector);
    try testing.expectEqualStrings("position", prop.name);
    try testing.expect(prop.type_annotation.base_type == .vec2);
    try testing.expect(prop.value == .vector);
    try testing.expectEqual(@as(usize, 2), prop.value.vector.len);
}

// Test parseProperty - bool property
test "parser.parseProperty - bool" {
    const src = "visible:bool true";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const prop = try parser.parseProperty();
    defer testing.allocator.free(prop.name);
    try testing.expectEqualStrings("visible", prop.name);
    try testing.expect(prop.type_annotation.base_type == .bool);
    try testing.expect(prop.value.boolean);
}

// Test parseProperty - string property
test "parser.parseProperty - string" {
    const src = "name:string \"test\"";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const prop = try parser.parseProperty();
    defer testing.allocator.free(prop.name);
    defer testing.allocator.free(prop.value.string);
    try testing.expectEqualStrings("name", prop.name);
    try testing.expectEqualStrings("test", prop.value.string);
}

// Test parseProperty - array property
test "parser.parseProperty - array" {
    const src = "values:f32[] {1.0, 2.0, 3.0}";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const prop = try parser.parseProperty();
    defer testing.allocator.free(prop.name);
    defer testing.allocator.free(prop.value.array);
    try testing.expectEqualStrings("values", prop.name);
    try testing.expect(prop.type_annotation.is_array);
    try testing.expect(prop.value == .array);
    try testing.expectEqual(@as(usize, 3), prop.value.array.len);
}

// Test check function
test "parser.check - matches current token" {
    const src = "[Player:entity]";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    try testing.expect(parser.check(.l_bracket));
    try testing.expect(!parser.check(.identifier));
}

// Test advance function
test "parser.advance - moves to next token" {
    const src = "[Player:entity]";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    try testing.expect(parser.current_tok.tag == .l_bracket);

    const prev = try parser.advance();
    try testing.expect(prev.tag == .l_bracket);
    try testing.expect(parser.current_tok.tag == .identifier);
}

// Test consume function
test "parser.consume - consumes expected token" {
    const src = "[Player";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const tok = try parser.consume(.l_bracket);
    try testing.expect(tok.tag == .l_bracket);
}

// Test consume function - error on wrong token
test "parser.consume - error on unexpected token" {
    const src = "[Player";
    var parser = try Parser.init(testing.allocator, src, "test.scene");
    const result = parser.consume(.identifier);
    try testing.expectError(error.UnexpectedToken, result);
}

// ============================================================================
// HIGH-LEVEL INTEGRATION TESTS
// ============================================================================

test "parser - simple entity" {
    const src = "[Player:entity]";
    const result = try parseSource(src);
    defer freeSceneFile(testing.allocator, result);

    try testing.expectEqual(@as(usize, 1), result.decls.len);
    try testing.expect(result.decls[0] == .entity);
    try testing.expectEqualStrings("Player", result.decls[0].entity.name);
    try testing.expectEqual(@as(usize, 0), result.decls[0].entity.components.len);
}

// Test entity with single component
test "parser - entity with component" {
    const src =
        \\[Player:entity]
        \\  [Transform]
    ;
    const result = try parseSource(src);
    defer freeSceneFile(testing.allocator, result);

    try testing.expectEqual(@as(usize, 1), result.decls.len);
    try testing.expect(result.decls[0] == .entity);
    try testing.expectEqualStrings("Player", result.decls[0].entity.name);
    try testing.expectEqual(@as(usize, 1), result.decls[0].entity.components.len);
    try testing.expectEqualStrings("Transform", result.decls[0].entity.components[0].name);
}

// Test component with f32 property
test "parser - component with f32 property" {
    const src =
        \\[Player:entity]
        \\  [Transform]
        \\    rotation:f32 0.0
    ;
    const result = try parseSource(src);
    defer freeSceneFile(testing.allocator, result);

    const entity = result.decls[0].entity;
    try testing.expectEqual(@as(usize, 1), entity.components.len);

    const component = entity.components[0];
    try testing.expectEqual(@as(usize, 1), component.properties.len);

    const prop = component.properties[0];
    try testing.expectEqualStrings("rotation", prop.name);
    try testing.expect(prop.type_annotation.base_type == .f32);
    try testing.expect(!prop.type_annotation.is_array);
    try testing.expect(prop.value == .number);
    try testing.expectEqual(@as(f64, 0.0), prop.value.number);
}

// Test component with vec2 property
test "parser - component with vec2 property" {
    const src =
        \\[Player:entity]
        \\  [Transform]
        \\    position:vec2 {0.0, 0.0}
    ;
    const result = try parseSource(src);
    defer freeSceneFile(testing.allocator, result);

    const prop = result.decls[0].entity.components[0].properties[0];
    try testing.expectEqualStrings("position", prop.name);
    try testing.expect(prop.type_annotation.base_type == .vec2);
    try testing.expect(!prop.type_annotation.is_array);
    try testing.expect(prop.value == .vector);
    try testing.expectEqual(@as(usize, 2), prop.value.vector.len);
    try testing.expectEqual(@as(f64, 0.0), prop.value.vector[0]);
    try testing.expectEqual(@as(f64, 0.0), prop.value.vector[1]);
}

// Test component with vec3 property
test "parser - component with vec3 property" {
    const src =
        \\[Player:entity]
        \\  [Transform]
        \\    scale:vec3 {1.0, 1.0, 1.0}
    ;
    const result = try parseSource(src);
    defer freeSceneFile(testing.allocator, result);

    const prop = result.decls[0].entity.components[0].properties[0];
    try testing.expectEqualStrings("scale", prop.name);
    try testing.expect(prop.type_annotation.base_type == .vec3);
    try testing.expect(prop.value == .vector);
    try testing.expectEqual(@as(usize, 3), prop.value.vector.len);
    try testing.expectEqual(@as(f64, 1.0), prop.value.vector[0]);
    try testing.expectEqual(@as(f64, 1.0), prop.value.vector[1]);
    try testing.expectEqual(@as(f64, 1.0), prop.value.vector[2]);
}

// Test negative numbers
test "parser - negative number property" {
    const src =
        \\[Player:entity]
        \\  [Transform]
        \\    x:f32 -5.0
        \\    y:f32 -10.5
    ;
    const result = try parseSource(src);
    defer freeSceneFile(testing.allocator, result);

    const props = result.decls[0].entity.components[0].properties;
    try testing.expectEqual(@as(usize, 2), props.len);
    try testing.expectEqual(@as(f64, -5.0), props[0].value.number);
    try testing.expectEqual(@as(f64, -10.5), props[1].value.number);
}

// Test negative vector components
test "parser - negative vector components" {
    const src =
        \\[Player:entity]
        \\  [Transform]
        \\    position:vec2 {-10.0, -20.5}
    ;
    const result = try parseSource(src);
    defer freeSceneFile(testing.allocator, result);

    const vec = result.decls[0].entity.components[0].properties[0].value.vector;
    try testing.expectEqual(@as(f64, -10.0), vec[0]);
    try testing.expectEqual(@as(f64, -20.5), vec[1]);
}

// Test boolean property
test "parser - boolean property" {
    const src =
        \\[Player:entity]
        \\  [Component]
        \\    visible:bool true
        \\    enabled:bool false
    ;
    const result = try parseSource(src);
    defer freeSceneFile(testing.allocator, result);

    const props = result.decls[0].entity.components[0].properties;
    try testing.expectEqual(@as(usize, 2), props.len);

    try testing.expectEqualStrings("visible", props[0].name);
    try testing.expect(props[0].type_annotation.base_type == .bool);
    try testing.expect(props[0].value == .boolean);
    try testing.expect(props[0].value.boolean);

    try testing.expectEqualStrings("enabled", props[1].name);
    try testing.expect(props[1].value == .boolean);
    try testing.expect(!props[1].value.boolean);
}

// Test string property
test "parser - string property" {
    const src =
        \\[Player:entity]
        \\  [Component]
        \\    name:string "Player One"
    ;
    const result = try parseSource(src);
    defer freeSceneFile(testing.allocator, result);

    const prop = result.decls[0].entity.components[0].properties[0];
    try testing.expectEqualStrings("name", prop.name);
    try testing.expect(prop.type_annotation.base_type == .string);
    try testing.expect(prop.value == .string);
    try testing.expectEqualStrings("Player One", prop.value.string);
}

// Test color property
test "parser - color property" {
    const src =
        \\[Player:entity]
        \\  [Renderer]
        \\    tint:color #FF6600
    ;
    const result = try parseSource(src);
    defer freeSceneFile(testing.allocator, result);

    const prop = result.decls[0].entity.components[0].properties[0];
    try testing.expectEqualStrings("tint", prop.name);
    try testing.expect(prop.type_annotation.base_type == .color);
    try testing.expect(prop.value == .color);
    try testing.expectEqual(@as(u32, 0xFF6600), prop.value.color);
}

// Test color with alpha
test "parser - color property with alpha" {
    const src =
        \\[Player:entity]
        \\  [Renderer]
        \\    tint:color #FF660080
    ;
    const result = try parseSource(src);
    defer freeSceneFile(testing.allocator, result);

    const prop = result.decls[0].entity.components[0].properties[0];
    try testing.expectEqual(@as(u32, 0xFF660080), prop.value.color);
}

// Test asset reference
test "parser - asset reference property" {
    const src =
        \\[Player:entity]
        \\  [Renderer]
        \\    texture:asset_ref "player_texture"
    ;
    const result = try parseSource(src);
    defer freeSceneFile(testing.allocator, result);

    const prop = result.decls[0].entity.components[0].properties[0];
    try testing.expectEqualStrings("texture", prop.name);
    try testing.expect(prop.type_annotation.base_type == .asset);
    try testing.expect(prop.value == .assetRef);
    try testing.expectEqualStrings("player_texture", prop.value.assetRef);
}

// Test multiple properties
test "parser - component with multiple properties" {
    const src =
        \\[Player:entity]
        \\  [Transform]
        \\    position:vec2 {0.0, 0.0}
        \\    rotation:f32 0.0
        \\    scale:vec2 {1.0, 1.0}
    ;
    const result = try parseSource(src);
    defer freeSceneFile(testing.allocator, result);

    const props = result.decls[0].entity.components[0].properties;
    try testing.expectEqual(@as(usize, 3), props.len);
    try testing.expectEqualStrings("position", props[0].name);
    try testing.expectEqualStrings("rotation", props[1].name);
    try testing.expectEqualStrings("scale", props[2].name);
}

// Test multiple components
test "parser - entity with multiple components" {
    const src =
        \\[Player:entity]
        \\  [Transform]
        \\    position:vec2 {0.0, 0.0}
        \\  [Renderer]
        \\    tint:color #FFFFFF
    ;
    const result = try parseSource(src);
    defer freeSceneFile(testing.allocator, result);

    const components = result.decls[0].entity.components;
    try testing.expectEqual(@as(usize, 2), components.len);
    try testing.expectEqualStrings("Transform", components[0].name);
    try testing.expectEqualStrings("Renderer", components[1].name);
}

// Test multiple entities
test "parser - multiple entities" {
    const src =
        \\[Player:entity]
        \\  [Transform]
        \\    position:vec2 {0.0, 0.0}
        \\[Enemy:entity]
        \\  [Transform]
        \\    position:vec2 {100.0, 100.0}
    ;
    const result = try parseSource(src);
    defer freeSceneFile(testing.allocator, result);

    try testing.expectEqual(@as(usize, 2), result.decls.len);
    try testing.expect(result.decls[0] == .entity);
    try testing.expect(result.decls[1] == .entity);
    try testing.expectEqualStrings("Player", result.decls[0].entity.name);
    try testing.expectEqualStrings("Enemy", result.decls[1].entity.name);
}

// Test scene declaration
test "parser - simple scene" {
    const src = "[MainScene:scene]";
    const result = try parseSource(src);
    defer freeSceneFile(testing.allocator, result);

    try testing.expectEqual(@as(usize, 1), result.decls.len);
    try testing.expect(result.decls[0] == .scene);
    try testing.expectEqualStrings("MainScene", result.decls[0].scene.name);
    try testing.expect(!result.decls[0].scene.is_container);
}

// Test scene with entities
test "parser - scene with entities" {
    const src =
        \\[MainScene:scene]
        \\  [Player:entity]
        \\    [Transform]
        \\      position:vec2 {0.0, 0.0}
    ;
    const result = try parseSource(src);
    defer freeSceneFile(testing.allocator, result);

    try testing.expect(result.decls[0] == .scene);
    const scene_decl = result.decls[0].scene;
    try testing.expect(scene_decl.is_container);
    try testing.expectEqual(@as(usize, 1), scene_decl.decls.len);
    try testing.expect(scene_decl.decls[0] == .entity);
}

// Test asset declaration
test "parser - asset declaration" {
    const src =
        \\[MyFont:asset font]
        \\  path:string "fonts/arial.ttf"
        \\  size:i32 24
    ;
    const result = try parseSource(src);
    defer freeSceneFile(testing.allocator, result);

    try testing.expectEqual(@as(usize, 1), result.decls.len);
    try testing.expect(result.decls[0] == .asset);

    const asset = result.decls[0].asset;
    try testing.expectEqualStrings("MyFont", asset.name);
    try testing.expect(asset.asset_type == .font);
    try testing.expectEqual(@as(usize, 2), asset.properties.len);
}

// Test array values
test "parser - array property" {
    const src =
        \\[Entity:entity]
        \\  [Component]
        \\    values:f32[] {1.0, 2.0, 3.0}
    ;
    const result = try parseSource(src);
    defer freeSceneFile(testing.allocator, result);

    const prop = result.decls[0].entity.components[0].properties[0];
    try testing.expect(prop.type_annotation.is_array);
    try testing.expect(prop.type_annotation.base_type == .f32);
    try testing.expect(prop.value == .array);
    try testing.expectEqual(@as(usize, 3), prop.value.array.len);
}

// Test integer types
test "parser - integer types" {
    const src =
        \\[Entity:entity]
        \\  [Component]
        \\    signed:i32 -42
        \\    unsigned:u32 100
    ;
    const result = try parseSource(src);
    defer freeSceneFile(testing.allocator, result);

    const props = result.decls[0].entity.components[0].properties;
    try testing.expectEqual(@as(usize, 2), props.len);

    try testing.expect(props[0].type_annotation.base_type == .i32);
    try testing.expectEqual(@as(f64, -42.0), props[0].value.number);

    try testing.expect(props[1].type_annotation.base_type == .u32);
    try testing.expectEqual(@as(f64, 100.0), props[1].value.number);
}

// Test empty component
test "parser - empty component" {
    const src =
        \\[Player:entity]
        \\  [EmptyComponent]
    ;
    const result = try parseSource(src);
    defer freeSceneFile(testing.allocator, result);

    const component = result.decls[0].entity.components[0];
    try testing.expectEqualStrings("EmptyComponent", component.name);
    try testing.expectEqual(@as(usize, 0), component.properties.len);
}

// Test comments are ignored
test "parser - comments ignored" {
    const src =
        \\// This is a comment
        \\[Player:entity]
        \\  // Another comment
        \\  [Transform]
        \\    position:vec2 {0.0, 0.0} // End of line comment
    ;
    const result = try parseSource(src);
    defer freeSceneFile(testing.allocator, result);

    try testing.expectEqual(@as(usize, 1), result.decls.len);
    try testing.expectEqualStrings("Player", result.decls[0].entity.name);
}

// Test complex nested structure
test "parser - complex nested structure" {
    const src =
        \\[MainScene:scene]
        \\  [Player:entity]
        \\    [Transform]
        \\      position:vec2 {0.0, 0.0}
        \\      rotation:f32 0.0
        \\    [Renderer]
        \\      tint:color #FFFFFF
        \\      visible:bool true
        \\  [Enemy:entity]
        \\    [Transform]
        \\      position:vec2 {100.0, 100.0}
    ;
    const result = try parseSource(src);
    defer freeSceneFile(testing.allocator, result);

    try testing.expect(result.decls[0] == .scene);
    const scene_decl = result.decls[0].scene;
    try testing.expectEqual(@as(usize, 2), scene_decl.decls.len);

    const player = scene_decl.decls[0].entity;
    try testing.expectEqual(@as(usize, 2), player.components.len);
    try testing.expectEqual(@as(usize, 2), player.components[0].properties.len);
    try testing.expectEqual(@as(usize, 2), player.components[1].properties.len);
}

// Test whitespace handling
test "parser - extra whitespace" {
    const src =
        \\[Player:entity]
        \\
        \\  [Transform]
        \\
        \\    position:vec2 {0.0, 0.0}
        \\
    ;
    const result = try parseSource(src);
    defer freeSceneFile(testing.allocator, result);

    try testing.expectEqual(@as(usize, 1), result.decls.len);
    const component = result.decls[0].entity.components[0];
    try testing.expectEqual(@as(usize, 1), component.properties.len);
}
