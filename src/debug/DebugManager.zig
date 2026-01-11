const std = @import("std");
const Allocator = std.mem.Allocator;
const Self = @This();
const DebugDraw = @import("DebugDraw.zig").DebugDraw;
const DebugRenderer = @import("DebugRenderer.zig");
const rend = @import("renderer");
const Renderer = rend.Renderer;
const assets = @import("asset");
const Font = assets.Font;

gpa: Allocator,
draw: DebugDraw,
renderer: DebugRenderer,

pub fn init(allocator: Allocator, renderer: *Renderer, default_font: *const Font) Self {
    return .{
        .gpa = allocator,
        .draw = .init(allocator),
        .renderer = .init(renderer, default_font),
    };
}
pub fn deinit(self: *Self) void {
    self.draw.deinit();
}

pub fn run(self: *Self, dt: f32) void {
    self.renderer.render(&self.draw);
    self.draw.update(dt);
}
