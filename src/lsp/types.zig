const sfmt = @import("scene_fmt");
pub const Diagnostic = sfmt.Diagnostic;

// MARK: Outbound data types
pub const Position = struct { line: u32, character: u32 };
pub const Range = struct { start: Position, end: Position };

const DiagnosticSeverity = enum(u8) {
    err = 1,
    warn = 2,
    info = 3,
    hint = 4,
};

pub const PublishDiagnosticParams = struct {
    uri: []const u8,
    diagnostics: []const Diagnostic,
};

pub const ServerCapabilities = struct {
    textDocumentSync: u8 = 1,
};

pub const InitializeResult = struct { capabilities: ServerCapabilities };

// MARK: Inbound data types
pub const TextDocumentItem = struct {
    uri: []const u8,
    languageId: []const u8,
    version: i64,
    text: []const u8,
};

pub const DidOpenParams = struct { textDocument: TextDocumentItem };

pub const VersionedId = struct { uri: []const u8, version: i64 };
pub const ContentChange = struct { text: []const u8 };
pub const DidChangeParams = struct {
    textDocument: VersionedId,
    contentChanges: []ContentChange,
};
pub const DidCloseParams = struct { textDocument: struct { uri: []const u8 } };
