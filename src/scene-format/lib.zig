const std = @import("std");
const tok = @import("token.zig");
pub const Token = tok.Token;
pub const TokenTag = tok.Token.Tag;
pub const Loc = tok.Loc;
const lex = @import("lexer.zig");
pub const Lexer = lex.Lexer;
pub const LexerError = lex.LexerError;
const par = @import("parser.zig");
pub const Parser = par.Parser;
pub const ParserError = par.ParseError;
const diag = @import("diagnostic.zig");
pub const Diagnostic = diag.Diagnostic;
pub const Severity = diag.Severity;
const ast = @import("ast.zig");
pub const Ast = ast.Ast;
pub const AssetDeclaration = ast.AssetDeclaration;
pub const AssetType = ast.AssetType;
pub const BaseType = ast.BaseType;
pub const TemplateDeclaration = ast.TemplateDeclaration;
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
pub const serialize = @import("writer.zig").serialize;
pub const LabelGraph = @import("graph.zig").LabelGraph;
const ingst = @import("ingest.zig");
pub const ingest = ingst.ingest;
pub const ingestResolved = ingst.ingestResolved;
const schem = @import("schema.zig");
pub const schema = schem.schema;
pub const Schema = schem.Schema;
pub const Literal = schem.Literal;
pub const FieldSpec = schem.FieldSpec;
pub const FieldType = schem.FieldType;
pub const Variant = schem.Variant;

pub fn lexeme(src: [:0]const u8, token: Token) []const u8 {
    const start = token.loc.start;
    const end = token.loc.end;
    return src[start..end];
}
pub fn parseString(
    gpa: std.mem.Allocator,
    src: [:0]const u8,
    file_name: []const u8,
) !SceneFile {
    var parser = try Parser.init(gpa, src, file_name);
    return try parser.parse();
}
