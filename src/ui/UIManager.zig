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
const log = @import("debug").log;

const Self = @This();

/// Internal storage for states of widgets
/// toggle: bit maskable for desired behaviours (hover, pressed, checked)
/// value: continuous states (sliders, spinners, etc...)
/// selection: indexes for dropdowns, tabs, radios, etc...
const WidgetState = union(enum) {
    toggle: u16,
    value: f16,
    selection: u16,
};

gpa: std.mem.Allocator,
arena: std.heap.ArenaAllocator,
root: ?*WidgetNode,
state_map: std.StringArrayHashMap(WidgetState),

pub fn init(backing_alloc: std.mem.Allocator) Self {
    return .{
        .gpa = backing_alloc,
        .arena = std.heap.ArenaAllocator.init(backing_alloc),
        .root = null,
        .state_map = .init(backing_alloc),
    };
}
pub fn deinit(self: *Self) void {
    self.arena.deinit();
    self.state_map.deinit();
}

pub fn getOrCreateState(
    self: *Self,
    id: []const u8,
    default: WidgetState,
) ?*WidgetState {
    const state = self.state_map.getOrPut(id) catch |err| {
        log.err(.ui, "Failed to create state for '{s}': {any}", .{ id, err });
        return null;
    };
    if (!state.found_existing) state.value_ptr.* = default;
    return state.value_ptr;
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
        dispatchEvent(self, root, &event);
    }
    if (left_up) {
        var event: Event = .{
            .kind = .mouse_up,
            .mouse_x = mouse_x,
            .mouse_y = mouse_y,
            .button = .left,
        };
        dispatchEvent(self, root, &event);
    }
    var event: Event = .{
        .kind = .mouse_move,
        .mouse_x = mouse_x,
        .mouse_y = mouse_y,
        .button = null,
    };
    dispatchEvent(self, root, &event);
}

fn dispatchEvent(self: *Self, node: *WidgetNode, event: *Event) void {
    if (event.consumed) return;
    switch (node.widget) {
        inline else => |*w| {
            // Wire up state pointer for any widget with an id
            // (needed by both handleEvent and render)
            if (@hasField(@TypeOf(w.*), "id")) {
                if (@hasField(@TypeOf(w.*), "state")) {
                    if (self.getOrCreateState(w.id, .{ .toggle = 0 })) |ws| {
                        w.state = &ws.toggle;
                    }
                }
            }
            if (@hasDecl(@TypeOf(w.*), "handleEvent")) {
                w.handleEvent(event, node.bounds);
            }
        },
    }

    switch (node.widget) {
        .Panel => |*p| dispatchEvent(self, p.child, event),
        .HStack => |*h| {
            for (h.children) |*c| dispatchEvent(self, c, event);
        },
        else => {},
    }
}
