const std = @import("std");
const Rect = @import("Rect.zig");
const l_out = @import("layout.zig");
const Constraints = l_out.Constraints;
const LayoutInfo = l_out.LayoutInfo;
const RenderInfo = l_out.RenderInfo;
const WidgetNode = @import("widgets/WidgetNode.zig");
pub const WidgetState = @import("widgetState.zig").WidgetState;
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

gpa: std.mem.Allocator,
arena: std.heap.ArenaAllocator,
root: ?*WidgetNode,
state_map: std.StringHashMap(WidgetState),
font: Font,

pub fn init(backing_alloc: std.mem.Allocator) Self {
    return .{
        .gpa = backing_alloc,
        .arena = std.heap.ArenaAllocator.init(backing_alloc),
        .root = null,
        .state_map = .init(backing_alloc),
        .font = Font.initFromMemory(
            backing_alloc,
            assets.embedded_default_font,
        ) catch |err| {
            log.fatal(
                .ui,
                "UIManager unable to load default font as fallback font: {any}",
                .{err},
            );
            @panic("UI System Failure");
        },
    };
}
pub fn deinit(self: *Self) void {
    self.font.deinit();
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

/// Read-only access to widget state by id.
/// Use this from builder code to read values (e.g., slider positions for color preview).
pub fn getState(self: *const Self, id: []const u8) ?*WidgetState {
    return self.state_map.getPtr(id);
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

// TODO: update for more styling/defaults later on
pub fn setFont(self: *Self, font: *const Font) void {
    self.font = font;
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
    const layout_info: LayoutInfo = .{
        .constraints = constraints,
        .font = &self.font,
        .pos = .{ .x = x, .y = y },
    };
    _ = root.layout(layout_info);
}

pub fn render(
    self: *Self,
    renderer: *Renderer,
    font: ?*const Font,
    ctx: RenderContext,
) void {
    const root = self.root orelse return;
    const render_info: RenderInfo = .{
        .bounds = root.bounds,
        .ctx = ctx,
        .renderer = renderer,
        .font = font orelse &self.font,
    };
    root.render(render_info);
}

pub fn processInput(
    self: *Self,
    mouse_x: f32,
    mouse_y: f32,
    left_down: bool,
    left_up: bool,
) void {
    const root = self.root orelse return;

    // Wire state pointers for ALL widgets first, independent of events.
    wireState(self, root);

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
        // Clear all dragging flags before dispatching mouse_up,
        // so drag never sticks (even on same-frame press+release).
        clearAllDragging(self);
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

/// Wire state pointers on every widget so rendering always works,
/// regardless of whether events were consumed.
fn wireState(self: *Self, node: *WidgetNode) void {
    switch (node.widget) {
        inline else => |*w| {
            const W = @TypeOf(w.*);
            if (@hasField(W, "id") and @hasDecl(W, "state_kind")) {
                const kind = W.state_kind;
                switch (kind) {
                    .flags => {
                        if (self.getOrCreateState(w.id, .{ .flags = 0 })) |ws| {
                            w.state = &ws.flags;
                        }
                    },
                    .value => {
                        if (self.getOrCreateState(
                            w.id,
                            .{ .value = .{ .val = 0, .flags = 0 } },
                        )) |ws| {
                            w.state_value = &ws.value.val;
                            w.state_flags = &ws.value.flags;
                        }
                    },
                    else => {},
                }
            }
        },
    }

    switch (node.widget) {
        .Panel => |*p| wireState(self, p.child),
        .HStack => |*h| {
            for (h.children) |*c| wireState(self, c);
        },
        .VStack => |*v| {
            for (v.children) |*c| wireState(self, c);
        },
        .Grid => |*g| {
            for (g.children) |*c| wireState(self, c);
        },
        else => {},
    }
}

/// Clear the DRAGGING flag on every value-state widget.
fn clearAllDragging(self: *Self) void {
    var it = self.state_map.iterator();
    while (it.next()) |entry| {
        switch (entry.value_ptr.*) {
            .value => |*v| v.flags &= ~@as(u16, 0x4),
            else => {},
        }
    }
}

fn dispatchEvent(node: *WidgetNode, event: *Event) void {
    if (event.consumed) return;
    switch (node.widget) {
        inline else => |*w| {
            const W = @TypeOf(w.*);
            if (@hasDecl(W, "handleEvent")) {
                w.handleEvent(event, node.bounds);
            }
        },
    }

    switch (node.widget) {
        .Panel => |*p| dispatchEvent(p.child, event),
        .HStack => |*h| {
            for (h.children) |*c| dispatchEvent(c, event);
        },
        .VStack => |*v| {
            for (v.children) |*c| dispatchEvent(c, event);
        },
        .Grid => |*g| {
            for (g.children) |*c| dispatchEvent(c, event);
        },
        else => {},
    }
}
