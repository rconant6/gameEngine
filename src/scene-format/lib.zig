const std = @import("std");
const tok = @import("token.zig");
pub const Token = tok.Token;
pub const TokenTag = tok.Token.Tag;
const lex = @import("lexer.zig");
pub const Lexer = lex.Lexer;
pub const LexerError = lex.LexerError;
const par = @import("parser.zig");
pub const Parser = par.Parser;
pub const ParserError = par.ParseError;
const ast = @import("ast.zig");
pub const AssetDeclaration = ast.AssetDeclaration;
pub const AssetType = ast.AssetType;
pub const BaseType = ast.BaseType;
pub const ComponentDeclaration = ast.ComponentDeclaration;
pub const Declaration = ast.Declaration;
pub const EntityDeclaration = ast.EntityDeclaration;
pub const GenericBlock = ast.GenericBlock;
pub const Property = ast.Property;
pub const SceneDeclaration = ast.SceneDeclaration;
pub const SceneFile = ast.SceneFile;
pub const SpriteBlock = ast.SpriteBlock;
pub const TypeAnnotation = ast.TypeAnnotation;
pub const Value = ast.Value;

pub fn lexeme(src: [:0]const u8, token: Token) []const u8 {
    const start = token.loc.start;
    const end = token.loc.end;
    return src[start..end];
}
pub fn parseString(
    allocator: std.mem.Allocator,
    src: [:0]const u8,
    file_name: []const u8,
) !SceneFile {
    var parser = try Parser.init(allocator, src, file_name);
    return try parser.parse();
}
