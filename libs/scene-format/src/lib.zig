const std = @import("std");
const tok = @import("token.zig");
pub const Token = tok.Token;
pub const TokenTag = tok.Token.Tag;
const lex = @import("lexer.zig");
const Lexer = lex.Lexer;
const par = @import("parser.zig");
pub const Parser = par.Parser;
const ast = @import("ast.zig");
pub const SceneFile = ast.SceneFile;
pub const Declaration = ast.Declaration;
pub const SceneDeclaration = ast.SceneDeclaration;
pub const EntityDeclaration = ast.EntityDeclaration;
pub const AssetDeclaration = ast.AssetDeclaration;
pub const ComponentDeclaration = ast.ComponentDeclaration;
pub const ShapeDeclaration = ast.ShapeDeclaration;
pub const ShapeBlock = ast.ShapeBlock;
pub const Property = ast.Property;
pub const TypeAnnotation = ast.TypeAnnotation;
pub const AssetType = ast.AssetType;
pub const BaseType = ast.BaseType;
pub const Value = ast.Value;
const errs = @import("scene_errors.zig");
pub const SceneError = errs.SceneError;
pub const ParserError = errs.ParseError;
pub const LexerError = errs.LexerError;

pub fn parseString(
    allocator: std.mem.Allocator,
    src: [:0]const u8,
    file_name: []const u8,
) !SceneFile {
    var parser = try Parser.init(allocator, src, file_name);
    return try parser.parse();
}
