const std = @import("std");
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");
const rend = @import("renderer");
const Renderer = rend.Renderer;

pub const debug_enabled = builtin.mode == .Debug;
// MARK: DebugManager
const DebugManagerImpl = @import("DebugManager.zig");
pub const DebugManager = if (debug_enabled) DebugManagerImpl else DebugManagerStub;
const DebugManagerStub = struct {
    draw: DebugDrawStub = .{},
    renderer: DebugRendererStub = .{},
    pub fn init(allocator: Allocator, renderer: *Renderer, default_font: anytype) @This() {
        _ = allocator;
        _ = renderer;
        _ = default_font;
        return .{};
    }
    pub fn deinit(self: *@This()) void {
        _ = self;
    }

    pub fn run(self: *@This(), dt: f32) void {
        _ = self;
        _ = dt;
    }
};

// MARK: DebugRender
const DebugRendererImpl = @import("DebugRenderer.zig");
pub const DebugRenderer = if (debug_enabled) DebugRendererImpl else DebugRendererStub;
const DebugRendererStub = struct {
    pub fn init(renderer: *Renderer, default_font: anytype) @This() {
        _ = renderer;
        _ = default_font;
        return .{};
    }
};
pub fn renderArrow(self: *@This(), arrow: DebugArrow) void {
    _ = self;
    _ = arrow;
}

pub fn renderCircle(self: *@This(), circle: DebugCircle) void {
    _ = self;
    _ = circle;
}
pub fn renderLine(self: *@This(), line: DebugLine) void {
    _ = self;
    _ = line;
}
pub fn renderRect(self: *@This(), rect: DebugRect) void {
    _ = self;
    _ = rect;
}
pub fn renderText(self: *@This(), text: DebugText) void {
    _ = self;
    _ = text;
}

// MARK: DebugDraw
const draw = @import("DebugDraw.zig");
pub const DebugArrow = draw.DebugArrow;
pub const DebugCircle = draw.DebugCircle;
pub const DebugLine = draw.DebugLine;
pub const DebugRect = draw.DebugRect;
pub const DebugText = draw.DebugText;
const DebugDrawImpl = draw.DebugDraw;
pub const DebugDraw = if (debug_enabled) DebugDrawImpl else DebugDrawStub;
pub const DebugCategory = draw.DebugCategory;
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
    pub fn init(allocator: std.mem.Allocator) @This() {
        _ = allocator;
        return .{};
    }
    pub fn deinit(self: *@This()) void {
        _ = self;
    }
    pub fn addArrow(self: *@This(), none: DebugArrow) !void {
        _ = self;
        _ = none;
    }
    pub fn addCircle(self: *@This(), none: DebugCircle) !void {
        _ = self;
        _ = none;
    }
    pub fn addLine(self: *@This(), none: DebugLine) !void {
        _ = self;
        _ = none;
    }
    pub fn addRect(self: *@This(), none: DebugRect) !void {
        _ = self;
        _ = none;
    }
    pub fn addText(self: *@This(), none: DebugText) !void {
        _ = self;
        _ = none;
    }
};
