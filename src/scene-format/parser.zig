const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const lex = @import("lexer.zig");
const Lexer = lex.Lexer;
const LexerError = lex.LexerError;
const lexeme = lex.lexeme;
const ast = @import("ast.zig");
const SceneFile = ast.SceneFile;
const Declaration = ast.Declaration;
const Property = ast.Property;
const Value = ast.Value;
const AssetType = ast.AssetType;

pub const ParseError = error{
    NoPreviousTokens,
    NoTokenReturned,
    UnclosedArrayBrackets,
    UnexpectedToken,
    Unimplemented,
    UnknownDeclarationType,
    UnknownType,
    UnknownAssetType,
    UnsupportedVectorLength,
    UnknownComponentType,
} || LexerError || @TypeOf(error.OutOfMemory) || @TypeOf(error.Overflow);

const toks = @import("token.zig");
const Token = toks.Token;
const TokenTag = toks.Token.Tag;

pub const Parser = struct {
    allocator: Allocator,
    lexer: Lexer,
    current_tok: Token,
    previous_tok: ?Token,
    file_name: []const u8,

    pub fn init(allocator: Allocator, src: [:0]const u8, file_name: []const u8) !Parser {
        var lexer = Lexer.init(src);
        const first = lexer.next() catch |err| {
            std.log.err("Lexer returned error on initialization {}", .{err});
            return err;
        } orelse {
            std.log.err("Lexer did not produce a token", .{});
            return ParseError.NoTokenReturned;
        };
        return Parser{
            .allocator = allocator,
            .lexer = lexer,
            .current_tok = first,
            .previous_tok = null,
            .file_name = file_name,
        };
    }

    pub fn parse(self: *Parser) !SceneFile {
        return self.parseSceneFile();
    }

    fn advance(self: *Parser) !Token {
        self.previous_tok = self.current_tok;
        self.current_tok = try self.lexer.next() orelse
            return ParseError.NoTokenReturned;

        return self.previous_tok orelse unreachable;
    }

    fn check(self: *Parser, token_type: TokenTag) bool {
        return self.current_tok.tag == token_type;
    }

    fn consume(self: *Parser, token_type: TokenTag) !Token {
        if (self.current_tok.tag != token_type) {
            return ParseError.UnexpectedToken;
        }

        const token = self.current_tok;
        _ = try self.advance();
        return token;
    }

    fn parseSceneFile(self: *Parser) !SceneFile {
        var declarations: ArrayList(Declaration) = .empty;
        errdefer {
            for (declarations.items) |*declaration| {
                declaration.deinit(self.allocator);
            }
            declarations.deinit(self.allocator);
        }
        while (self.current_tok.tag != .eof) {
            const decl = try self.parseDeclaration();
            try declarations.append(self.allocator, decl);
        }
        return .{
            .decls = try declarations.toOwnedSlice(self.allocator),
            .source_file_name = try self.allocator.dupe(u8, self.file_name),
        };
    }

    // MARK: Declarations
    fn parseDeclaration(self: *Parser) ParseError!Declaration {
        // NOTE: consume [name:, dispatch on keyword
        _ = try self.consume(.l_bracket);
        const name_token = try self.consume(.identifier);
        _ = try self.consume(.colon);
        switch (self.current_tok.tag) {
            .scene => return .{ .scene = try self.parseSceneDeclaration(name_token) },
            .entity => return .{ .entity = try self.parseEntityDeclaration(name_token) },
            .asset => return .{ .asset = try self.parseAssetDeclaration(name_token) },
            .template => return .{ .template = try self.parseTemplateDeclaration(name_token) },
            else => return ParseError.UnknownDeclarationType,
        }
    }

    fn parseSceneDeclaration(self: *Parser, name_token: Token) !ast.SceneDeclaration {
        // NOTE: [name:scene], check for INDENT, parse children or label
        const name_str = lex.lexeme(self.lexer.src, name_token);
        const name = try self.allocator.dupe(u8, name_str);
        errdefer self.allocator.free(name);
        _ = try self.consume(.scene);
        _ = try self.consume(.r_bracket);

        var is_container = false;
        var declarations: ArrayList(ast.Declaration) = .empty;
        errdefer {
            for (declarations.items) |*declaration| {
                declaration.deinit(self.allocator);
            }
            declarations.deinit(self.allocator);
        }
        if (self.check(.indent)) {
            _ = try self.consume(.indent);
            is_container = true;
            while (!self.check(.dedent)) {
                const decl = try self.parseDeclaration();
                try declarations.append(self.allocator, decl);
            }
            _ = try self.consume(.dedent);
        }

        return .{
            .name = name,
            .is_container = is_container,
            .decls = try declarations.toOwnedSlice(self.allocator),
            .location = name_token.src_loc,
        };
    }

    fn parseTemplateDeclaration(self: *Parser, name_token: Token) !ast.TemplateDeclaration {
        // NOTE: [name:template], expect INDENT, loop components
        const name_str = lex.lexeme(self.lexer.src, name_token);
        const name = try self.allocator.dupe(u8, name_str);
        errdefer self.allocator.free(name);
        _ = try self.consume(.template);
        _ = try self.consume(.r_bracket);

        var components: ArrayList(ast.ComponentDeclaration) = .empty;
        errdefer {
            for (components.items) |*component| {
                component.deinit(self.allocator);
            }
            components.deinit(self.allocator);
        }
        if (self.check(.indent)) {
            _ = try self.consume(.indent);
            while (!self.check(.dedent)) {
                _ = try self.consume(.l_bracket);
                const comp_name_token = try self.consume(.identifier);
                const comp = try self.parseComponentBlock(comp_name_token);
                try components.append(self.allocator, comp);
            }
            _ = try self.consume(.dedent);
        }

        return .{
            .name = name,
            .components = try components.toOwnedSlice(self.allocator),
            .location = name_token.src_loc,
        };
    }

    fn parseEntityDeclaration(self: *Parser, name_token: Token) !ast.EntityDeclaration {
        // NOTE: [name:entity], expect INDENT, loop components
        const name_str = lex.lexeme(self.lexer.src, name_token);
        const name = try self.allocator.dupe(u8, name_str);
        errdefer self.allocator.free(name);
        _ = try self.consume(.entity);
        _ = try self.consume(.r_bracket);

        var components: ArrayList(ast.ComponentDeclaration) = .empty;
        errdefer {
            for (components.items) |*component| {
                component.deinit(self.allocator);
            }
            components.deinit(self.allocator);
        }
        if (self.check(.indent)) {
            _ = try self.consume(.indent);
            while (!self.check(.dedent)) {
                _ = try self.consume(.l_bracket);
                const comp_name_token = try self.consume(.identifier);
                const comp = try self.parseComponentBlock(comp_name_token);
                try components.append(self.allocator, comp);
            }
            _ = try self.consume(.dedent);
        }

        return .{
            .name = name,
            .components = try components.toOwnedSlice(self.allocator),
            .location = name_token.src_loc,
        };
    }

    fn parseAssetDeclaration(self: *Parser, name_token: Token) !ast.AssetDeclaration {
        // NOTE: [name:asset type], parse properties
        const name = lex.lexeme(self.lexer.src, name_token);
        _ = try self.consume(.asset);

        const asset_type: ast.AssetType = switch (self.current_tok.tag) {
            .font => .font,
            else => return ParseError.UnknownAssetType,
        };
        _ = try self.advance(); // Consume the asset type token
        _ = try self.consume(.r_bracket);

        var properties: ArrayList(Property) = .empty;
        errdefer properties.deinit(self.allocator);
        if (self.check(.indent)) {
            _ = try self.consume(.indent);
            while (!self.check(.dedent)) {
                const prop = try self.parseProperty();
                try properties.append(self.allocator, prop);
            }
            _ = try self.consume(.dedent);
        }

        return .{
            .name = try self.allocator.dupe(u8, name),
            .properties = try properties.toOwnedSlice(self.allocator),
            .location = name_token.src_loc,
            .asset_type = asset_type,
        };
    }

    fn parseComponentDeclaration(self: *Parser, name_token: Token) !ast.ComponentDeclaration {
        return try self.parseComponentBlock(name_token);
    }

    fn parseComponentBlock(self: *Parser, name_token: Token) !ast.ComponentDeclaration {
        const component_name = lex.lexeme(self.lexer.src, name_token);

        if (std.mem.eql(u8, "Sprite", component_name)) {
            return try self.parseSpriteBlock(name_token);
        }
        if (std.mem.eql(u8, "Collider", component_name)) {
            return try self.parseColliderBlock(name_token);
        }
        _ = try self.consume(.r_bracket);

        const block_name = try self.allocator.dupe(u8, component_name);
        errdefer self.allocator.free(block_name);

        var properties: ArrayList(Property) = .empty;
        errdefer {
            for (properties.items) |*prop| {
                prop.deinit(self.allocator);
            }
            properties.deinit(self.allocator);
        }

        var nested_blocks: ?[]ast.GenericBlock = null;
        errdefer {
            if (nested_blocks) |blocks| {
                for (blocks) |*block| {
                    block.deinit();
                }
                self.allocator.free(blocks);
            }
        }

        if (self.check(.indent)) {
            _ = try self.consume(.indent);

            // NOTE: all properties must precede the nested blocks
            while (!self.check(.dedent) and
                !self.check(.indent) and
                !self.check(.l_bracket))
            {
                const prop = try self.parseProperty();
                try properties.append(self.allocator, prop);
            }

            if (self.check(.dedent)) {
                _ = try self.consume(.dedent);
                return ast.ComponentDeclaration{ .generic = .{
                    .allocator = self.allocator,
                    .location = name_token.src_loc,
                    .name = block_name,
                    .nested_blocks = null,
                    .properties = if (properties.items.len > 0) try properties.toOwnedSlice(self.allocator) else null,
                } };
            }

            if (self.check(.l_bracket)) {
                nested_blocks = try self.parseNestedBlocks();
                _ = try self.consume(.dedent);
            }
        }

        return ast.ComponentDeclaration{ .generic = .{
            .allocator = self.allocator,
            .location = name_token.src_loc,
            .name = block_name,
            .nested_blocks = nested_blocks,
            .properties = if (properties.items.len > 0) try properties.toOwnedSlice(self.allocator) else null,
        } };
    }

    fn parseNestedBlocks(self: *Parser) ![]ast.GenericBlock {
        var siblings: ArrayList(ast.GenericBlock) = .empty;
        errdefer {
            for (siblings.items) |*block| {
                block.deinit();
            }
            siblings.deinit(self.allocator);
        }

        while (!self.check(.dedent)) {
            _ = try self.consume(.l_bracket);
            const name_token = try self.consume(.identifier);
            const component_name = lex.lexeme(self.lexer.src, name_token);
            _ = try self.consume(.r_bracket);

            const block_name = try self.allocator.dupe(u8, component_name);
            errdefer self.allocator.free(block_name);

            var properties: ArrayList(Property) = .empty;
            errdefer {
                for (properties.items) |*prop| {
                    prop.deinit(self.allocator);
                }
                properties.deinit(self.allocator);
            }

            var nested_blocks: ?[]ast.GenericBlock = null;
            errdefer {
                if (nested_blocks) |blocks| {
                    for (blocks) |*block| {
                        block.deinit();
                    }
                    self.allocator.free(blocks);
                }
            }

            if (self.check(.indent)) {
                _ = try self.consume(.indent);

                while (!self.check(.dedent) and !self.check(.l_bracket)) {
                    const prop = try self.parseProperty();
                    try properties.append(self.allocator, prop);
                }

                if (self.check(.l_bracket)) {
                    nested_blocks = try self.parseNestedBlocks();
                }

                _ = try self.consume(.dedent);
            }

            const parent_block = ast.GenericBlock{
                .allocator = self.allocator,
                .location = name_token.src_loc,
                .name = block_name,
                .nested_blocks = nested_blocks,
                .properties = if (properties.items.len > 0) try properties.toOwnedSlice(self.allocator) else null,
            };

            try siblings.append(self.allocator, parent_block);
        }

        return try siblings.toOwnedSlice(self.allocator);
    }

    fn parseSpriteBlock(self: *Parser, name_token: Token) !ast.ComponentDeclaration {
        const name_str = lex.lexeme(self.lexer.src, name_token);
        const name = try self.allocator.dupe(u8, name_str);
        errdefer self.allocator.free(name);
        _ = try self.consume(.colon);

        const shape_type_token = try self.consume(.identifier);
        const type_name = lex.lexeme(self.lexer.src, shape_type_token);
        _ = try self.consume(.r_bracket);

        var properties: ArrayList(Property) = .empty;
        errdefer properties.deinit(self.allocator);
        if (self.check(.indent)) {
            _ = try self.consume(.indent);
            while (!self.check(.dedent)) {
                const prop = try self.parseProperty();
                try properties.append(self.allocator, prop);
            }
            _ = try self.consume(.dedent);
        }

        return ast.ComponentDeclaration{ .sprite = .{
            .name = name,
            .shape_type = try self.allocator.dupe(u8, type_name),
            .properties = try properties.toOwnedSlice(self.allocator),
            .location = name_token.src_loc,
            .allocator = self.allocator,
        } };
    }
    fn parseColliderBlock(self: *Parser, name_token: Token) !ast.ComponentDeclaration {
        const name_str = lex.lexeme(self.lexer.src, name_token);
        const name = try self.allocator.dupe(u8, name_str);
        errdefer self.allocator.free(name);
        _ = try self.consume(.colon);

        const shape_type_token = try self.consume(.identifier);
        const type_name = lex.lexeme(self.lexer.src, shape_type_token);
        _ = try self.consume(.r_bracket);

        var properties: ArrayList(Property) = .empty;
        errdefer properties.deinit(self.allocator);
        if (self.check(.indent)) {
            _ = try self.consume(.indent);
            while (!self.check(.dedent)) {
                const prop = try self.parseProperty();
                try properties.append(self.allocator, prop);
            }
            _ = try self.consume(.dedent);
        }

        return ast.ComponentDeclaration{ .collider = .{
            .name = name,
            .shape_type = try self.allocator.dupe(u8, type_name),
            .properties = try properties.toOwnedSlice(self.allocator),
            .location = name_token.src_loc,
            .allocator = self.allocator,
        } };
    }

    fn parseProperty(self: *Parser) !Property {
        const name_token = try self.consume(.identifier);
        const name = lex.lexeme(self.lexer.src, name_token);

        _ = try self.consume(.colon);

        const type_annotation = try self.parseTypeAnnotation();
        var value = try self.parseValue(type_annotation);
        errdefer value.deinit(self.allocator);
        const location = name_token.src_loc;

        return Property{
            .name = try self.allocator.dupe(u8, name),
            .type_annotation = type_annotation,
            .value = value,
            .location = location,
        };
    }

    fn parseTypeAnnotation(self: *Parser) !ast.TypeAnnotation {
        const base_type: ast.BaseType = switch (self.current_tok.tag) {
            .vec2 => .vec2,
            .vec3 => .vec3,
            .f32 => .f32,
            .i32 => .i32,
            .u32 => .u32,
            .bool => .bool,
            .string => .string,
            .color => .color,
            .asset_ref => .asset,
            .action => .action,
            .action_target => .action_target,
            .key => .key,
            .mouse => .mouse,
            else => return ParseError.UnknownType,
        };
        _ = try self.advance(); // Consume the type token

        const is_array = if (self.check(.l_bracket)) blk: {
            _ = try self.consume(.l_bracket);
            _ = try self.consume(.r_bracket);
            break :blk true;
        } else false;

        return .{
            .base_type = base_type,
            .is_array = is_array,
        };
    }

    fn parseValue(self: *Parser, type_annotation: ast.TypeAnnotation) !Value {
        if (type_annotation.is_array == true) {
            return try self.parseArrayValue(type_annotation.base_type);
        } else {
            return try self.parseSingleValue(type_annotation.base_type);
        }
    }

    fn parseArrayValue(self: *Parser, element_type: ast.BaseType) !Value {
        _ = try self.consume(.l_brace);

        const has_indent = self.check(.indent);
        if (has_indent) _ = try self.advance();

        var vals: ArrayList(Value) = .empty;
        errdefer {
            for (vals.items) |*item| {
                item.deinit(self.allocator);
            }
            vals.deinit(self.allocator);
        }
        if (!self.check(.r_brace)) {
            var val = try self.parseSingleValue(element_type);
            try vals.append(self.allocator, val);

            while (!self.check(.r_brace) and !self.check(.dedent)) {
                _ = try self.consume(.comma);
                val = try self.parseSingleValue(element_type);
                try vals.append(self.allocator, val);
            }
        }

        if (has_indent and self.check(.dedent)) _ = try self.advance();
        _ = try self.consume(.r_brace);

        return Value{ .array = try vals.toOwnedSlice(self.allocator) };
    }

    fn parseSingleValue(self: *Parser, base_type: ast.BaseType) !Value {
        return switch (base_type) {
            .vec2 => try self.parseVectorValue(2),
            .vec3 => try self.parseVectorValue(3),

            .f32, .i32, .u32 => Value{ .number = try self.parseNumber() },

            .bool => blk: {
                const val = if (self.check(.true)) true else false;
                _ = try self.consume(if (val) .true else .false);
                break :blk Value{ .boolean = val };
            },

            .string => blk: {
                const str_token = try self.consume(.string_lit);
                const str_lexeme = lex.lexeme(self.lexer.src, str_token);
                const str_copy = try self.allocator.dupe(u8, str_lexeme);
                break :blk Value{ .string = str_copy };
            },

            .color => blk: {
                const color_token = try self.consume(.color_lit);
                const hex_str = lex.lexeme(self.lexer.src, color_token);
                const color_val = try std.fmt.parseInt(u32, hex_str, 16);
                break :blk Value{ .color = color_val };
            },

            .asset => blk: {
                const asset_token = try self.consume(.string_lit);
                const asset_name = lex.lexeme(self.lexer.src, asset_token);
                const asset_copy = try self.allocator.dupe(u8, asset_name);
                break :blk Value{ .assetRef = asset_copy };
            },
            .action => blk: {
                const action_token = try self.consume(.identifier);
                const action_name = lex.lexeme(self.lexer.src, action_token);
                break :blk Value{
                    .action_type = try self.allocator.dupe(u8, action_name),
                };
            },
            .action_target => blk: {
                const target_token = try self.consume(.identifier);
                const target_name = lex.lexeme(self.lexer.src, target_token);
                break :blk Value{
                    .action_target = try self.allocator.dupe(u8, target_name),
                };
            },
            .key => blk: {
                const key_token = try self.consume(.identifier);
                const key_name = lex.lexeme(self.lexer.src, key_token);
                break :blk Value{
                    .key_input = try self.allocator.dupe(u8, key_name),
                };
            },
            .mouse => blk: {
                const mouse_token = try self.consume(.identifier);
                const mouse_name = lex.lexeme(self.lexer.src, mouse_token);
                break :blk Value{
                    .mouse_input = try self.allocator.dupe(u8, mouse_name),
                };
            },
        };
    }

    fn parseVectorValue(self: *Parser, arity: u8) !Value {
        _ = try self.consume(.l_brace);

        if (arity != 2 and arity != 3) {
            std.log.err("Only supporting vec2 or vec3 not vec{d}", .{arity});
            return ParseError.UnsupportedVectorLength;
        }

        var arr = try self.allocator.alloc(f64, arity);
        errdefer self.allocator.free(arr);

        var num = try self.parseNumber();
        arr[0] = num;
        for (1..arity) |i| {
            _ = try self.consume(.comma);
            num = try self.parseNumber();
            arr[i] = num;
        }

        _ = try self.consume(.r_brace);

        return Value{ .vector = arr };
    }

    fn parseNumber(self: *Parser) !f64 {
        const isNegative = self.check(.minus);
        if (isNegative) {
            _ = try self.consume(.minus);
        }

        const num_token = try self.consume(.number);
        const num_str = lex.lexeme(self.lexer.src, num_token);
        const value = try std.fmt.parseFloat(f64, num_str);

        return if (isNegative) -value else value;
    }
};
