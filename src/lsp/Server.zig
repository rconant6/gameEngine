const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const json = std.json;
const Transport = @import("Transport.zig");
const ds = @import("doc_store.zig");
const DocStore = ds.DocStore;
const rpc = @import("rpc.zig");
const dc = @import("doc_store.zig");
const Document = dc.Document;
const tps = @import("types.zig");
const InitializeResult = tps.InitializeResult;
const ServerCapabilities = tps.ServerCapabilities;
const PublishDiagnosticParams = tps.PublishDiagnosticParams;
const diag = @import("diagnostics.zig");
const Diagnostic = diag.Diagnostic;
const cmp = @import("completion.zig");

const Self = @This();

gpa: Allocator,
transport: Transport,
docs: DocStore,
state: State = .waiting_initialize,

const State = enum { waiting_initialize, running, shutting_down };

pub fn init(gpa: Allocator, transport: Transport) Self {
    return .{
        .gpa = gpa,
        .transport = transport,
        .docs = .{ .gpa = gpa },
    };
}
pub fn deinit(self: *Self) void {
    self.docs.deinit();
}
pub fn run(self: *Self) !void {
    while (!(self.state == .shutting_down)) {
        const body = self.transport.readMessage() catch |e| switch (e) {
            error.EndOfStream => break,
            else => return e,
        };
        // free the body no matter how this iteration exits (incl. a parse error)
        defer self.gpa.free(body);

        var inc = try rpc.parse(self.gpa, body);
        defer inc.deinit();

        try self.handle(inc.msg);
    }
}

fn handle(self: *Self, msg: rpc.Message) !void {
    if (std.mem.eql(u8, msg.method, "initialize")) {
        // a request MUST carry an id; a malformed id-less one gets an error, not a panic
        const id = msg.id orelse return rpc.writeError(
            &self.transport,
            self.gpa,
            null,
            -32600, // InvalidRequest
            "initialize requires an id",
        );
        return self.onInitialize(id);
    }
    if (std.mem.eql(u8, msg.method, "initialized")) {
        // notification, ignore
        return;
    }
    if (std.mem.eql(u8, msg.method, "textDocument/didOpen")) {
        return self.onDidOpen(msg.params);
    }
    if (std.mem.eql(u8, msg.method, "textDocument/didChange")) {
        return self.onDidChange(msg.params);
    }
    if (std.mem.eql(u8, msg.method, "textDocument/didClose")) {
        return self.onDidClose(msg.params);
    }
    if (std.mem.eql(u8, msg.method, "textDocument/completion")) {
        const id = msg.id orelse return rpc.writeError(
            &self.transport,
            self.gpa,
            null,
            -32600, // InvalidRequest
            "textDocument/completion requires an id",
        );
        return self.onCompletion(id, msg.params);
    }
    if (std.mem.eql(u8, msg.method, "shutdown")) {
        const id = msg.id orelse return rpc.writeError(
            &self.transport,
            self.gpa,
            null,
            -32600, // InvalidRequest
            "shutdown requires an id",
        );
        return self.onShutdown(id);
    }
    if (std.mem.eql(u8, msg.method, "exit")) {
        return;
    }

    // TODO: handle this error if request
}
fn onInitialize(self: *Self, id: rpc.Message.Id) !void {
    try rpc.writeResponse(
        &self.transport,
        self.gpa,
        id,
        InitializeResult{ .capabilities = .{} }, // textDocumentSync defaults to 1 (Full)
    );
}

fn onDidOpen(self: *Self, params: json.Value) !void {
    const parsed = try json.parseFromValue(
        tps.DidOpenParams,
        self.gpa,
        params,
        .{ .ignore_unknown_fields = true }, // clients send fields we don't model
    );
    defer parsed.deinit(); // upsert dupes the strings into the store; safe to free after
    const td = parsed.value.textDocument;
    const doc = try self.docs.upsert(td.uri, td.version, td.text);

    try self.compileAndPublish(doc);
}

fn onDidChange(self: *Self, params: json.Value) !void {
    const parsed = try json.parseFromValue(
        tps.DidChangeParams,
        self.gpa,
        params,
        .{ .ignore_unknown_fields = true }, // clients send fields we don't model
    );
    defer parsed.deinit();
    const last = parsed.value.contentChanges.len - 1;
    const lc = parsed.value.contentChanges[last];
    const td = parsed.value.textDocument;
    const doc = try self.docs.upsert(td.uri, td.version, lc.text);

    try self.compileAndPublish(doc);
}

fn onCompletion(self: *Self, id: rpc.Message.Id, params: json.Value) !void {
    const parsed = try json.parseFromValue(
        tps.CompletionParams,
        self.gpa,
        params,
        .{ .ignore_unknown_fields = true }, // clients send fields we don't model
    );
    defer parsed.deinit();

    var arena = ArenaAllocator.init(self.gpa);
    defer arena.deinit();

    const doc = self.docs.get(parsed.value.textDocument.uri) orelse
        return rpc.writeResponse(
            &self.transport,
            arena.allocator(),
            id,
            &[_]tps.CompletionItem{},
        );

    const byte = doc.lines.byteOf(parsed.value.position);
    const items = try cmp.complete(arena.allocator(), doc.src, byte);

    try rpc.writeResponse(&self.transport, arena.allocator(), id, items);
}

fn onDidClose(self: *Self, params: json.Value) !void {
    const parsed = try json.parseFromValue(
        tps.DidCloseParams,
        self.gpa,
        params,
        .{ .ignore_unknown_fields = true }, // clients send fields we don't model
    );
    defer parsed.deinit();
    const uri = parsed.value.textDocument.uri;

    self.docs.close(uri);
}
fn onShutdown(self: *Self, id: rpc.Message.Id) !void {
    _ = id;
    self.state = .shutting_down;
}
fn compileAndPublish(self: *Self, doc: *Document) !void {
    var arena = ArenaAllocator.init(self.gpa);
    // var alloc = arena.allocator();
    defer arena.deinit();

    // TODO: add in the diagnostics folder
    const diags = try diag.collect(
        arena.allocator(),
        doc.src,
        doc.lines,
    );

    try rpc.writeNotification(
        &self.transport,
        arena.allocator(),
        "textDocument/publishDiagnostics",
        PublishDiagnosticParams{
            .uri = doc.uri,
            .diagnostics = diags,
        },
    );
}
