const std = @import("std");
const testing = std.testing;

const scene = @import("lib");
const Lexer = scene.Lexer;
const Token = scene.Token;
const TokenTag = scene.TokenTag;

fn expectToken(lexer: *Lexer, expected_tag: TokenTag) !void {
    const token = try lexer.next();
    try testing.expect(token != null);
    try testing.expectEqual(expected_tag, token.?.tag);
}

fn expectTokenWithLexeme(
    lexer: *Lexer,
    expected_tag: TokenTag,
    src: [:0]const u8,
    expected_lexeme: []const u8,
) !void {
    const token = try lexer.next();
    try testing.expect(token != null);
    try testing.expectEqual(expected_tag, token.?.tag);
    const actual_lexeme = src[token.?.loc.start..token.?.loc.end];
    try testing.expectEqualStrings(expected_lexeme, actual_lexeme);
}

// Test basic single character tokens
test "lexer - single character tokens" {
    const src = "[]{},:.-";
    var lexer = Lexer.init(src);

    try expectToken(&lexer, .l_bracket);
    try expectToken(&lexer, .r_bracket);
    try expectToken(&lexer, .l_brace);
    try expectToken(&lexer, .r_brace);
    try expectToken(&lexer, .comma);
    try expectToken(&lexer, .colon);
    // NOTE: .dot is not a standalone token, only used in numbers
    const result = lexer.next();
    try testing.expectError(error.InvalidCharacter, result);
}

// Test keywords
test "lexer - keywords" {
    const src = "scene entity asset shape vec2 vec3 f32 i32 u32 bool string color asset_ref true false";
    var lexer = Lexer.init(src);

    try expectToken(&lexer, .scene);
    try expectToken(&lexer, .entity);
    try expectToken(&lexer, .asset);
    try expectToken(&lexer, .shape);
    try expectToken(&lexer, .vec2);
    try expectToken(&lexer, .vec3);
    try expectToken(&lexer, .f32);
    try expectToken(&lexer, .i32);
    try expectToken(&lexer, .u32);
    try expectToken(&lexer, .bool);
    try expectToken(&lexer, .string);
    try expectToken(&lexer, .color);
    try expectToken(&lexer, .asset_ref);
    try expectToken(&lexer, .true);
    try expectToken(&lexer, .false);
    try expectToken(&lexer, .eof);
}

// Test identifiers
test "lexer - identifiers" {
    const src = "myVar _private Component123 CONSTANT";
    var lexer = Lexer.init(src);

    try expectTokenWithLexeme(&lexer, .identifier, src, "myVar");
    try expectTokenWithLexeme(&lexer, .identifier, src, "_private");
    try expectTokenWithLexeme(&lexer, .identifier, src, "Component123");
    try expectTokenWithLexeme(&lexer, .identifier, src, "CONSTANT");
    try expectToken(&lexer, .eof);
}

// Test numbers (integers)
test "lexer - integer numbers" {
    const src = "0 42 123 999";
    var lexer = Lexer.init(src);

    try expectTokenWithLexeme(&lexer, .number, src, "0");
    try expectTokenWithLexeme(&lexer, .number, src, "42");
    try expectTokenWithLexeme(&lexer, .number, src, "123");
    try expectTokenWithLexeme(&lexer, .number, src, "999");
    try expectToken(&lexer, .eof);
}

// Test numbers (floats)
test "lexer - float numbers" {
    const src = "0.0 3.14 123.456 0.5";
    var lexer = Lexer.init(src);

    try expectTokenWithLexeme(&lexer, .number, src, "0.0");
    try expectTokenWithLexeme(&lexer, .number, src, "3.14");
    try expectTokenWithLexeme(&lexer, .number, src, "123.456");
    try expectTokenWithLexeme(&lexer, .number, src, "0.5");
    try expectToken(&lexer, .eof);
}

// Test negative numbers
test "lexer - negative numbers" {
    const src = "-5 -3.14";
    var lexer = Lexer.init(src);

    try expectToken(&lexer, .minus);
    try expectTokenWithLexeme(&lexer, .number, src, "5");
    try expectToken(&lexer, .minus);
    try expectTokenWithLexeme(&lexer, .number, src, "3.14");
    try expectToken(&lexer, .eof);
}

// Test strings
test "lexer - strings" {
    const src = "\"hello\" \"world\" \"with spaces\" \"\"";
    var lexer = Lexer.init(src);

    try expectTokenWithLexeme(&lexer, .string_lit, src, "hello");
    try expectTokenWithLexeme(&lexer, .string_lit, src, "world");
    try expectTokenWithLexeme(&lexer, .string_lit, src, "with spaces");
    try expectTokenWithLexeme(&lexer, .string_lit, src, "");
    try expectToken(&lexer, .eof);
}

// Test multiline strings
test "lexer - multiline strings" {
    const src = "\"line1\nline2\"";
    var lexer = Lexer.init(src);

    try expectToken(&lexer, .string_lit);
    try expectToken(&lexer, .eof);
}

// Test colors (6 hex digits)
test "lexer - colors 6 digits" {
    const src = "#FF0000 #00FF00 #0000FF #FFFFFF #000000 #abcdef";
    var lexer = Lexer.init(src);

    try expectTokenWithLexeme(&lexer, .color_lit, src, "FF0000");
    try expectTokenWithLexeme(&lexer, .color_lit, src, "00FF00");
    try expectTokenWithLexeme(&lexer, .color_lit, src, "0000FF");
    try expectTokenWithLexeme(&lexer, .color_lit, src, "FFFFFF");
    try expectTokenWithLexeme(&lexer, .color_lit, src, "000000");
    try expectTokenWithLexeme(&lexer, .color_lit, src, "abcdef");
    try expectToken(&lexer, .eof);
}

// Test colors (8 hex digits with alpha)
test "lexer - colors 8 digits" {
    const src = "#FF0000FF #00FF0080 #0000FFAA";
    var lexer = Lexer.init(src);

    try expectTokenWithLexeme(&lexer, .color_lit, src, "FF0000FF");
    try expectTokenWithLexeme(&lexer, .color_lit, src, "00FF0080");
    try expectTokenWithLexeme(&lexer, .color_lit, src, "0000FFAA");
    try expectToken(&lexer, .eof);
}

// Test comments
test "lexer - comments" {
    const src = "// this is a comment\nidentifier";
    var lexer = Lexer.init(src);

    try expectToken(&lexer, .identifier);
    try expectToken(&lexer, .eof);
}

// Test single level indentation
test "lexer - single indent" {
    const src =
        \\parent
        \\  child
    ;
    var lexer = Lexer.init(src);

    try expectToken(&lexer, .identifier); // parent
    try expectToken(&lexer, .indent);
    try expectToken(&lexer, .identifier); // child
    try expectToken(&lexer, .dedent);
    try expectToken(&lexer, .eof);
}

// Test multiple indent levels
test "lexer - multiple indents" {
    const src =
        \\level0
        \\  level1
        \\    level2
        \\      level3
    ;
    var lexer = Lexer.init(src);

    try expectToken(&lexer, .identifier); // level0
    try expectToken(&lexer, .indent);
    try expectToken(&lexer, .identifier); // level1
    try expectToken(&lexer, .indent);
    try expectToken(&lexer, .identifier); // level2
    try expectToken(&lexer, .indent);
    try expectToken(&lexer, .identifier); // level3
    try expectToken(&lexer, .dedent);
    try expectToken(&lexer, .dedent);
    try expectToken(&lexer, .dedent);
    try expectToken(&lexer, .eof);
}

// Test dedent to previous level
test "lexer - dedent" {
    const src =
        \\level0
        \\  level1
        \\    level2
        \\  back_to_level1
        \\back_to_level0
    ;
    var lexer = Lexer.init(src);

    try expectToken(&lexer, .identifier); // level0
    try expectToken(&lexer, .indent);
    try expectToken(&lexer, .identifier); // level1
    try expectToken(&lexer, .indent);
    try expectToken(&lexer, .identifier); // level2
    try expectToken(&lexer, .dedent);
    try expectToken(&lexer, .identifier); // back_to_level1
    try expectToken(&lexer, .dedent);
    try expectToken(&lexer, .identifier); // back_to_level0
    try expectToken(&lexer, .eof);
}

// Test empty lines
test "lexer - empty lines" {
    const src =
        \\identifier1
        \\
        \\identifier2
        \\
        \\
        \\identifier3
    ;
    var lexer = Lexer.init(src);

    try expectToken(&lexer, .identifier);
    try expectToken(&lexer, .identifier);
    try expectToken(&lexer, .identifier);
    try expectToken(&lexer, .eof);
}

// Test scene format entity declaration
test "lexer - entity declaration" {
    const src = "[Player:entity]";
    var lexer = Lexer.init(src);

    try expectToken(&lexer, .l_bracket);
    try expectToken(&lexer, .identifier);
    try expectToken(&lexer, .colon);
    try expectToken(&lexer, .entity);
    try expectToken(&lexer, .r_bracket);
    try expectToken(&lexer, .eof);
}

// Test property with type and value
test "lexer - property declaration" {
    const src = "position:vec2 {0.0, 0.0}";
    var lexer = Lexer.init(src);

    try expectToken(&lexer, .identifier); // position
    try expectToken(&lexer, .colon);
    try expectToken(&lexer, .vec2);
    try expectToken(&lexer, .l_brace);
    try expectToken(&lexer, .number);
    try expectToken(&lexer, .comma);
    try expectToken(&lexer, .number);
    try expectToken(&lexer, .r_brace);
    try expectToken(&lexer, .eof);
}

// Test boolean property
test "lexer - boolean property" {
    const src = "visible:bool true";
    var lexer = Lexer.init(src);

    try expectToken(&lexer, .identifier);
    try expectToken(&lexer, .colon);
    try expectToken(&lexer, .bool);
    try expectToken(&lexer, .true);
    try expectToken(&lexer, .eof);
}

// Test color property
test "lexer - color property" {
    const src = "fill_color:color #FF6600";
    var lexer = Lexer.init(src);

    try expectToken(&lexer, .identifier);
    try expectToken(&lexer, .colon);
    try expectToken(&lexer, .color);
    try expectToken(&lexer, .color_lit);
    try expectToken(&lexer, .eof);
}

// Test full entity with component
test "lexer - full entity" {
    const src =
        \\[Player:entity]
        \\  [Transform]
        \\    position:vec2 {0.0, 0.0}
        \\    rotation:f32 0.0
    ;
    var lexer = Lexer.init(src);

    // [Player:entity]
    try expectToken(&lexer, .l_bracket);
    try expectToken(&lexer, .identifier);
    try expectToken(&lexer, .colon);
    try expectToken(&lexer, .entity);
    try expectToken(&lexer, .r_bracket);

    // [Transform]
    try expectToken(&lexer, .indent);
    try expectToken(&lexer, .l_bracket);
    try expectToken(&lexer, .identifier);
    try expectToken(&lexer, .r_bracket);

    // position:vec2 {0.0, 0.0}
    try expectToken(&lexer, .indent);
    try expectToken(&lexer, .identifier);
    try expectToken(&lexer, .colon);
    try expectToken(&lexer, .vec2);
    try expectToken(&lexer, .l_brace);
    try expectToken(&lexer, .number);
    try expectToken(&lexer, .comma);
    try expectToken(&lexer, .number);
    try expectToken(&lexer, .r_brace);

    // rotation:f32 0.0
    try expectToken(&lexer, .identifier);
    try expectToken(&lexer, .colon);
    try expectToken(&lexer, .f32);
    try expectToken(&lexer, .number);

    try expectToken(&lexer, .dedent);
    try expectToken(&lexer, .dedent);
    try expectToken(&lexer, .eof);
}

// Error tests
test "lexer - invalid color (5 digits)" {
    const src = "#12345";
    var lexer = Lexer.init(src);

    const result = lexer.next();
    try testing.expectError(error.InvalidColor, result);
}

test "lexer - invalid color (7 digits)" {
    const src = "#1234567";
    var lexer = Lexer.init(src);

    const result = lexer.next();
    try testing.expectError(error.InvalidColor, result);
}

test "lexer - unclosed string" {
    const src = "\"unclosed";
    var lexer = Lexer.init(src);

    const result = lexer.next();
    try testing.expectError(error.UnclosedString, result);
}

test "lexer - invalid number (dot without trailing digits)" {
    const src = "5.x";
    var lexer = Lexer.init(src);

    const result = lexer.next();
    try testing.expectError(error.InvalidNumber, result);
}

test "lexer - standalone dot is invalid" {
    const src = ".";
    var lexer = Lexer.init(src);

    const result = lexer.next();
    try testing.expectError(error.InvalidCharacter, result);
}

test "lexer - invalid characters" {
    const src = "@ $ % ^ & * ( ) = + ! ~ ` | \\ < > ?";
    var lexer = Lexer.init(src);

    var i: usize = 0;
    while (i < 18) : (i += 1) {
        const result = lexer.next();
        try testing.expectError(error.InvalidCharacter, result);
    }
}

test "lexer - single slash is invalid (not a comment)" {
    const src = "/ hello";
    var lexer = Lexer.init(src);

    const result = lexer.next();
    try testing.expectError(error.InvalidCharacter, result);
}

test "lexer - tab indentation error" {
    const src = "\tidentifier";
    var lexer = Lexer.init(src);

    const result = lexer.next();
    try testing.expectError(error.TabIndentationFound, result);
}

test "lexer - invalid indentation increment (3 spaces)" {
    const src =
        \\parent
        \\   child
    ;
    var lexer = Lexer.init(src);

    _ = try lexer.next(); // parent
    const result = lexer.next();
    try testing.expectError(error.InvalidIndentation, result);
}

test "lexer - invalid indentation decrement (odd spaces)" {
    const src =
        \\parent
        \\  child1
        \\    child2
        \\   bad
    ;
    var lexer = Lexer.init(src);

    _ = try lexer.next(); // parent
    _ = try lexer.next(); // indent
    _ = try lexer.next(); // child1
    _ = try lexer.next(); // indent
    _ = try lexer.next(); // child2
    const result = lexer.next();
    try testing.expectError(error.InvalidIndentation, result);
}

test "lexer - comment at start of line with indentation" {
    const src =
        \\parent
        \\  // comment
        \\  child
    ;
    var lexer = Lexer.init(src);

    try expectToken(&lexer, .identifier); // parent
    try expectToken(&lexer, .indent);
    try expectToken(&lexer, .identifier); // child
    try expectToken(&lexer, .dedent);
    try expectToken(&lexer, .eof);
}

test "lexer - multiple entities" {
    const src =
        \\[Entity1:entity]
        \\  [Transform]
        \\    position:vec2 {1.0, 2.0}
        \\[Entity2:entity]
        \\  [Transform]
        \\    position:vec2 {3.0, 4.0}
    ;
    var lexer = Lexer.init(src);

    // Entity1
    try expectToken(&lexer, .l_bracket);
    try expectToken(&lexer, .identifier);
    try expectToken(&lexer, .colon);
    try expectToken(&lexer, .entity);
    try expectToken(&lexer, .r_bracket);
    try expectToken(&lexer, .indent);
    try expectToken(&lexer, .l_bracket);
    try expectToken(&lexer, .identifier);
    try expectToken(&lexer, .r_bracket);
    try expectToken(&lexer, .indent);
    try expectToken(&lexer, .identifier);
    try expectToken(&lexer, .colon);
    try expectToken(&lexer, .vec2);
    try expectToken(&lexer, .l_brace);
    try expectToken(&lexer, .number);
    try expectToken(&lexer, .comma);
    try expectToken(&lexer, .number);
    try expectToken(&lexer, .r_brace);
    try expectToken(&lexer, .dedent);
    try expectToken(&lexer, .dedent);

    // Entity2
    try expectToken(&lexer, .l_bracket);
    try expectToken(&lexer, .identifier);
    try expectToken(&lexer, .colon);
    try expectToken(&lexer, .entity);
    try expectToken(&lexer, .r_bracket);
    try expectToken(&lexer, .indent);
    try expectToken(&lexer, .l_bracket);
    try expectToken(&lexer, .identifier);
    try expectToken(&lexer, .r_bracket);
    try expectToken(&lexer, .indent);
    try expectToken(&lexer, .identifier);
    try expectToken(&lexer, .colon);
    try expectToken(&lexer, .vec2);
    try expectToken(&lexer, .l_brace);
    try expectToken(&lexer, .number);
    try expectToken(&lexer, .comma);
    try expectToken(&lexer, .number);
    try expectToken(&lexer, .r_brace);
    try expectToken(&lexer, .dedent);
    try expectToken(&lexer, .dedent);
    try expectToken(&lexer, .eof);
}

test "lexer - deep nesting (16 levels)" {
    const src =
        \\level0
        \\  level1
        \\    level2
        \\      level3
        \\        level4
        \\          level5
        \\            level6
        \\              level7
        \\                level8
        \\                  level9
        \\                    level10
        \\                      level11
        \\                        level12
        \\                          level13
        \\                            level14
        \\                              level15
    ;
    var lexer = Lexer.init(src);

    // Level 0
    try expectToken(&lexer, .identifier);

    // Indent to each level (1-15)
    var level: u32 = 1;
    while (level <= 15) : (level += 1) {
        try expectToken(&lexer, .indent);
        try expectToken(&lexer, .identifier);
    }

    // Dedent back to level 0 (15 dedents)
    var dedent_count: u32 = 0;
    while (dedent_count < 15) : (dedent_count += 1) {
        try expectToken(&lexer, .dedent);
    }

    try expectToken(&lexer, .eof);
}

test "lexer - deep nesting with jump back to level 0" {
    const src =
        \\level0
        \\  level1
        \\    level2
        \\      level3
        \\        level4
        \\          level5
        \\            level6
        \\              level7
        \\                level8
        \\back_to_level0
    ;
    var lexer = Lexer.init(src);

    // Level 0
    try expectToken(&lexer, .identifier);

    // Indent to each level (1-8)
    var level: u32 = 1;
    while (level <= 8) : (level += 1) {
        try expectToken(&lexer, .indent);
        try expectToken(&lexer, .identifier);
    }

    // Jump back to level 0 (8 dedents)
    var dedent_count: u32 = 0;
    while (dedent_count < 8) : (dedent_count += 1) {
        try expectToken(&lexer, .dedent);
    }

    // Back at level 0
    try expectToken(&lexer, .identifier);
    try expectToken(&lexer, .eof);
}
