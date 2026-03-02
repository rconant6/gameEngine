const std = @import("std");
const Rect = @import("Rect.zig");
const l_out = @import("layout.zig");
const Constraints = l_out.Constraints;
const WidgetNode = @import("widgets/WidgetNode.zig");
const rend = @import("renderer");
const Renderer = rend.Renderer;
const RenderContext = rend.RenderContext;
const assets = @import("assets");
const Font = assets.Font;

const Self = @This();

arena: std.heap.ArenaAllocator,
root: ?*WidgetNode,

pub fn init(backing_alloc: std.mem.Allocator) Self {
    return .{
        .arena = std.heap.ArenaAllocator.init(backing_alloc),
        .root = null,
    };
}
pub fn deinit(self: *Self) void {
    self.arena.deinit();
}

pub fn rebuild(self: *Self) void {
    _ = self.arena.reset(.retain_capacity);
    self.root = null;
}

pub fn allocator(self: *Self) std.mem.Allocator {
    return self.arena.allocator();
}

pub fn setRoot(self: *Self, node: *WidgetNode) void {
    self.root = node;
}

pub fn layout(
    self: *Self,
    screen_width: f32,
    screen_height: f32,
) void {
    self.layoutAt(0, 0, screen_width, screen_height);
}

pub fn layoutAt(
    self: *Self,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
) void {
    const root = self.root orelse return;
    const constraints = Constraints.loose(width, height);
    _ = root.layout(constraints, x, y);
}

pub fn render(self: *Self, renderer: *Renderer, font: *const Font, ctx: RenderContext) void {
    const root = self.root orelse return;
    root.render(renderer, font, ctx);
}
