const std = @import("std");
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");
const rend = @import("renderer");
const Renderer = rend.Renderer;
pub const log = @import("log.zig");
pub const LogLevel = log.LogLevel;
pub const LogCategory = log.LogCategory;
pub const LogEntry = log.LogEntry;
pub const Logger = log.Logger;
pub const debug_enabled = builtin.mode == .Debug;

// MARK: DebugManager
const DebugManagerImpl = @import("DebugManager.zig");
pub const DebugManager = if (debug_enabled)
    DebugManagerImpl
else
    DebugManagerStub;

const DebugManagerStub = struct {
    draw: DebugDrawStub = .{},
    renderer: DebugRendererStub = .{},
    pub fn init(
        frame: Allocator,
        persistent: Allocator,
        renderer: *Renderer,
        default_font: anytype,
        default_tex: anytype,
    ) @This() {
        _ = frame;
        _ = persistent;
        _ = renderer;
        _ = default_font;
        _ = default_tex;
        return .{};
    }
    pub fn deinit(self: *@This()) void {
        _ = self;
    }
    pub fn beginFrame(self: *@This()) void {
        _ = self;
    }
    pub fn toggleCategory(self: *@This(), category: anytype) void {
        _ = self;
        _ = category;
    }
    pub fn run(self: *@This(), dt: f32, ctx: anytype) void {
        _ = self;
        _ = dt;
        _ = ctx;
    }
};

// MARK: DebugRender
const DebugRendererImpl = @import("DebugRenderer.zig");
pub const DebugRenderer = if (debug_enabled)
    DebugRendererImpl
else
    DebugRendererStub;

const DebugRendererStub = struct {
    pub fn init(renderer: *Renderer, default_font: anytype, default_tex: anytype) @This() {
        _ = renderer;
        _ = default_font;
        _ = default_tex;
        return .{};
    }
    pub fn renderArrow(self: *@This(), arrow: DebugArrow, ctx: anytype) void {
        _ = self;
        _ = arrow;
        _ = ctx;
    }
    pub fn renderCircle(self: *@This(), circle: DebugCircle, ctx: anytype) void {
        _ = self;
        _ = circle;
        _ = ctx;
    }
    pub fn renderLine(self: *@This(), line: DebugLine, ctx: anytype) void {
        _ = self;
        _ = line;
        _ = ctx;
    }
    pub fn renderRect(self: *@This(), rect: DebugRect, ctx: anytype) void {
        _ = self;
        _ = rect;
        _ = ctx;
    }
    pub fn renderText(self: *@This(), text: DebugText, ctx: anytype) void {
        _ = self;
        _ = text;
        _ = ctx;
    }
    pub fn render(self: *@This(), data: *const DebugDraw, ctx: anytype) void {
        _ = self;
        _ = data;
        _ = ctx;
    }
};

// MARK: DebugDraw
const draw = @import("DebugDraw.zig");
pub const DebugArrow = draw.DebugArrow;
pub const DebugCategory = draw.DebugCategory;
pub const DebugCircle = draw.DebugCircle;
pub const DebugLine = draw.DebugLine;
pub const DebugRect = draw.DebugRect;
pub const DebugText = draw.DebugText;
const DebugDrawImpl = draw.DebugDraw;
const DebugCategoryEnum = draw.DebugCategoryEnum;
pub const DebugDraw = if (debug_enabled)
    DebugDrawImpl
else
    DebugDrawStub;

const DebugDrawStub = struct {
    pub fn update(self: *@This(), dt: f32) void {
        _ = self;
        _ = dt;
    }
    pub fn toggleCategory(self: *DebugDraw, category: DebugCategory) void {
        _ = self;
        _ = category;
    }
    pub fn clear(self: *@This()) void {
        _ = self;
    }
    pub fn clearCategory(self: *DebugDraw, cat: DebugCategory) void {
        _ = self;
        _ = cat;
    }
    pub fn init(frame: std.mem.Allocator, persistent: std.mem.Allocator) @This() {
        _ = frame;
        _ = persistent;
        return .{};
    }
    pub fn deinit(self: *@This()) void {
        _ = self;
    }
    pub fn addArrow(self: *@This(), none: DebugArrow) void {
        _ = self;
        _ = none;
    }
    pub fn addCircle(self: *@This(), none: DebugCircle) void {
        _ = self;
        _ = none;
    }
    pub fn addLine(self: *@This(), none: DebugLine) void {
        _ = self;
        _ = none;
    }
    pub fn addRect(self: *@This(), none: DebugRect) void {
        _ = self;
        _ = none;
    }
    pub fn addText(self: *@This(), none: DebugText) void {
        _ = self;
        _ = none;
    }
};

// MARK: Stub/Impl parity
// The stubs above are hand-written parallel copies of the real types, selected
// by build mode. Nothing forces them to agree, and because only one side is
// compiled per build, drift in the release stubs is invisible from a Debug
// build -- it surfaces as an arity error at a distant call site the first time
// someone builds release. These checks move that failure here, to the
// definition, in every build mode.
//
// Rule: the stub must expose every public method the impl has, with the same
// parameter count. Extra stub methods are allowed; a missing or wrong-arity one
// is the drift we care about. Parameter *types* are deliberately not compared --
// stubs legitimately widen concrete types to `anytype`.
fn assertStubParity(comptime Impl: type, comptime Stub: type, comptime label: []const u8) void {
    for (@typeInfo(Impl).@"struct".decls) |decl| {
        const impl_field = @field(Impl, decl.name);
        const impl_info = @typeInfo(@TypeOf(impl_field));
        if (impl_info != .@"fn") continue;

        if (!@hasDecl(Stub, decl.name)) {
            @compileError(label ++ " stub is missing method '" ++ decl.name ++ "'");
        }
        const stub_info = @typeInfo(@TypeOf(@field(Stub, decl.name)));
        if (stub_info != .@"fn") {
            @compileError(label ++ " stub's '" ++ decl.name ++ "' is not a function");
        }
        if (impl_info.@"fn".params.len != stub_info.@"fn".params.len) {
            @compileError(std.fmt.comptimePrint(
                "{s} stub's '{s}' takes {d} param(s), impl takes {d}",
                .{ label, decl.name, stub_info.@"fn".params.len, impl_info.@"fn".params.len },
            ));
        }
    }
}

comptime {
    assertStubParity(DebugManagerImpl, DebugManagerStub, "DebugManager");
    assertStubParity(DebugRendererImpl, DebugRendererStub, "DebugRenderer");
    assertStubParity(DebugDrawImpl, DebugDrawStub, "DebugDraw");
}
