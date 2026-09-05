pub const sfmt = @import("scene_fmt");
pub const SceneDiagnostic = sfmt.Diagnostic;
pub const Ast = sfmt.Ast;
pub const diag = @import("diagnostics.zig");
const Diagnostic = diag.Diagnostic;

// MARK: Outbound data types
pub const Position = struct { line: u32, character: u32 };
pub const Range = struct { start: Position, end: Position };

pub const PublishDiagnosticParams = struct {
    uri: []const u8,
    diagnostics: []const Diagnostic,
};

pub const ServerCapabilities = struct {
    textDocumentSync: u8 = 1,
    completionProvider: struct {
        triggerCharacters: []const []const u8 = &.{ ":", " " },
    } = .{},
};

pub const InitializeResult = struct { capabilities: ServerCapabilities };

// MARK: Inbound data types
pub const TextDocumentItem = struct {
    uri: []const u8,
    languageId: []const u8,
    version: i64,
    text: []const u8,
};
pub const CompletionItemKind = enum(u8) {
    text = 1,
    method = 2,
    field = 5,
    value = 12,
    keyword = 14,
    enum_member = 20,
    struct_ = 22,

    pub fn jsonStringify(self: @This(), jw: anytype) !void {
        try jw.write(@intFromEnum(self));
    }
};

pub const CompletionItem = struct {
    label: []const u8,
    kind: CompletionItemKind,
    detail: []const u8 = "",
    documentation: []const u8 = "",
};

pub const DidOpenParams = struct { textDocument: TextDocumentItem };

pub const VersionedId = struct { uri: []const u8, version: i64 };
pub const ContentChange = struct { text: []const u8 };
pub const DidChangeParams = struct {
    textDocument: VersionedId,
    contentChanges: []ContentChange,
};
pub const DidCloseParams = struct { textDocument: struct { uri: []const u8 } };
pub const CompletionParams = struct {
    textDocument: struct { uri: []const u8 },
    position: Position,
};
