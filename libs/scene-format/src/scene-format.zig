const std = @import("std");
const lex = @import("lexer.zig");
pub const Lexer = lex.Lexer;
const tok = @import("token.zig");
pub const Token = tok.Token;
pub const TokenTag = Token.Tag;

pub fn main() !void {
    const test_scene =
        \\// Test comment to start!
        \\[TestScene:scene]
        \\
        \\// Font assets
        \\[Orbitron:asset font]
        \\  path:string "Orbitron.ttf"
        \\
        \\[Bangers:asset font]
        \\  path:string "Bangers.ttf"
        \\
        \\// Bouncing circle entity
        \\[Bouncer:entity]
        \\  [Transform]
        \\    position:vec2 {0.0, 0.0}
        \\    rotation:f32 0.0
        \\    scale:f32 1.0
        \\
        \\  [Velocity]
        \\    linear:vec2 {5.0, 3.0}
        \\    angular:f32 0.0
        \\
        \\  [Sprite]
        \\    [Circle:shape]
        \\      origin:vec2 {0.0, 0.0}
        \\      radius:f32 2.0
        \\      fill_color:color #00FF00
        \\      outline_color:color #FFFFFF
        \\    visible:bool true
        \\
        \\  [ScreenClamp]
        \\
        \\// Text display entity
        \\[TextDisplay:entity]
        \\  [Transform]
        \\    position:vec2 {-8.0, 9.0}
        \\    rotation:f32 0.0
        \\    scale:f32 1.0
        \\
        \\  [Text]
        \\    text:string "ECS DEMO - Bouncing & Wrapping"
        \\    font:asset Orbitron
        \\    scale:f32 0.5
        \\    color:color #FF6600
        \\
        \\// Wrapping rectangle entity
        \\[Wrapper:entity]
        \\  [Transform]
        \\    position:vec2 {-5.0, -5.0}
        \\    rotation:f32 0.0
        \\    scale:f32 1.0
        \\
        \\  [Velocity]
        \\    linear:vec2 {2.0, 1.5}
        \\    angular:f32 1.0
        \\
        \\  [Sprite]
        \\    [Rectangle:shape]
        \\      center:vec2 {0.0, 0.0}
        \\      width:f32 3.0
        \\      height:f32 2.0
        \\      fill_color:color #8800FF
        \\      outline_color:color #FFFFFF
        \\    visible:bool true
        \\
        \\  [ScreenWrap]
        \\
        \\// Timed triangle entity
        \\[StaticTri:entity]
        \\  [Transform]
        \\    position:vec2 {0.0, 5.0}
        \\    rotation:f32 0.0
        \\    scale:f32 1.0
        \\
        \\  [Sprite]
        \\    [Triangle:shape]
        \\      vertices:vec2[] {{0.0, 1.0}, {-1.0, -1.0}, {1.0, -1.0}}
        \\      fill_color:color #0000FF
        \\      outline_color:color #FFFFFF
        \\    visible:bool true
        \\
        \\  [Lifetime]
        \\    remaining:f32 2.0
        \\[Entity1:entity]
        \\  [Transform]
        \\    position:vec2 {1.0, 2.0}
        \\[Entity2:entity]
        \\  [Transform]
        \\    position:vec2 {3.0, 4.0}
    ;
    var lexer: Lexer = .init(test_scene);
    var token_count: usize = 0;
    var token_tag: TokenTag = .invalid;
    while (true and token_tag != .eof) {
        const token = lexer.next() catch |err| {
            std.debug.print("ERR: {} at {f}\n", .{ err, lexer.src_loc });
            break;
        } orelse break;
        token_count += 1;
        token_tag = token.tag;
        std.log.debug("[TAG] {} [LEXEME]{s}", .{ token.tag, lexeme(token, lexer.src) });
    }
    std.log.info(
        "[LEXER] found {d} tokens\n[LEXER] indentLevel: {d}\n[LEXER] dedents left: {d}",
        .{ token_count, lexer.indent_level, lexer.dedents_left },
    );
}

fn lexeme(token: Token, src: [:0]const u8) []const u8 {
    const start = token.loc.start;
    const end = token.loc.end;
    return src[start..end];
}
