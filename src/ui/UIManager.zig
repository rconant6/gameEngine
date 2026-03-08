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
const evt = @import("event.zig");
const Event = evt.Event;
const EventKind = evt.EventKind;
const MouseButton = evt.MouseButton;

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

pub fn processInput(self: *Self, mouse_x: f32, mouse_y: f32, left_down: bool, left_up: bool) void {
    const root = self.root orelse return;

    if (left_down) {
        var event: Event = .{
            .kind = .mouse_down,
            .mouse_x = mouse_x,
            .mouse_y = mouse_y,
            .button = .left,
        };
        dispatchEvent(root, &event);
    }
    if (left_up) {
        var event: Event = .{
            .kind = .mouse_up,
            .mouse_x = mouse_x,
            .mouse_y = mouse_y,
            .button = .left,
        };
        dispatchEvent(root, &event);
    }
    var event: Event = .{
        .kind = .mouse_move,
        .mouse_x = mouse_x,
        .mouse_y = mouse_y,
        .button = null,
    };
    dispatchEvent(root, &event);
}

fn dispatchEvent(node: *WidgetNode, event: *Event) void {
    if (event.consumed) return;

    switch (node.widget) {
        inline else => |*w| {
            if (@hasDecl(@TypeOf(w.*), "handleEvent")) {
                w.handleEvent(event, node.bounds);
            }
        },
    }

    switch (node.widget) {
        .Panel => |*p| dispatchEvent(p.child, event),
        .HStack => |*h| {
            for (h.children) |*c| dispatchEvent(c, event);
        },
        else => {},
    }
}
