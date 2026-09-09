const std = @import("std");
const l_out = @import("layout.zig");
const Constraints = l_out.Constraints;
const LayoutInfo = l_out.LayoutInfo;
const RenderInfo = l_out.RenderInfo;
const WidgetNode = @import("widgets/WidgetNode.zig");
pub const WidgetState = @import("widgetState.zig").WidgetState;
const rend = @import("renderer");
const Renderer = rend.Renderer;
const Texture = Renderer.Texture;
const assets = @import("assets");
const Font = assets.Font;
const evt = @import("event.zig");
const Event = evt.Event;
const EventKind = evt.EventKind;
const MouseButton = evt.MouseButton;
const UIInput = evt.UIInput;
const log = @import("debug").log;

const Self = @This();

persistent: std.mem.Allocator,
arena: std.heap.ArenaAllocator,
root: ?*WidgetNode,
state_map: std.StringHashMap(WidgetState),
font: Font,

pub fn init(backing_alloc: std.mem.Allocator) Self {
    return .{
        .persistent = backing_alloc,
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
    var keys = self.state_map.keyIterator();
    while (keys.next()) |k| self.persistent.free(k.*);
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
    if (!state.found_existing) {
        // The map owns its keys: ids are often built on the frame arena
        // (allocPrint in a builder), which `rebuild` resets every frame.
        state.key_ptr.* = self.persistent.dupe(u8, id) catch |err| {
            log.err(.ui, "Failed to own state id '{s}': {any}", .{ id, err });
            self.state_map.removeByPtr(state.key_ptr);
            return null;
        };
        state.value_ptr.* = default;
    }
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

/// Wires state here, not in processInput: the tree is rebuilt from the arena
/// every frame (every `.state` starts null), and layout, input and render all
/// read state. Non-interactive views never call processInput at all.
pub fn setRoot(self: *Self, node: *WidgetNode) void {
    self.root = node;
    wireState(self, node);
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
    tex: *Texture,
    ctx: anytype,
) void {
    const root = self.root orelse return;
    const render_info: RenderInfo = .{
        .bounds = root.bounds,
        .ctx = ctx,
        .renderer = renderer,
        .font = font orelse &self.font,
        .tex = tex,
    };
    root.render(render_info);
}

pub fn processInput(self: *Self, in: UIInput) void {
    const root = self.root orelse return;

    if (in.left_down) {
        // Blur = commit: unfocus every text field before the click lands; the
        // field that was hit re-focuses itself. Works even when an earlier
        // widget consumes the click.
        blurAll(self);
        var event: Event = .{
            .kind = .mouse_down,
            .mouse_x = in.mouse_x,
            .mouse_y = in.mouse_y,
            .button = .left,
        };
        dispatchEvent(root, &event);
    }
    if (in.left_up) {
        // Clear all dragging flags before dispatching mouse_up,
        // so drag never sticks (even on same-frame press+release).
        clearAllDragging(self);
        var event: Event = .{
            .kind = .mouse_up,
            .mouse_x = in.mouse_x,
            .mouse_y = in.mouse_y,
            .button = .left,
        };
        dispatchEvent(root, &event);
    }

    if (in.scroll_delta != 0) {
        var e: Event = .{
            .kind = .mouse_scroll,
            .mouse_x = in.mouse_x,
            .mouse_y = in.mouse_y,
            .button = null,
            .scroll_delta = in.scroll_delta,
        };
        dispatchEvent(root, &e);
    }

    // Keys before text, after mouse_down: click-to-focus lands before any
    // same-frame typing.
    for (in.keys()) |k| {
        var e: Event = .{
            .kind = .key_down,
            .mouse_x = in.mouse_x,
            .mouse_y = in.mouse_y,
            .button = null,
            .key = k,
        };
        dispatchEvent(root, &e);
    }
    for (in.text) |cp| {
        var e: Event = .{
            .kind = .text_input,
            .mouse_x = in.mouse_x,
            .mouse_y = in.mouse_y,
            .button = null,
            .char = cp,
        };
        dispatchEvent(root, &e);
    }

    var event: Event = .{
        .kind = .mouse_move,
        .mouse_x = in.mouse_x,
        .mouse_y = in.mouse_y,
        .button = null,
    };
    dispatchEvent(root, &event);
}

/// True while a text field is being edited. Hosts use it to suppress their
/// own key shortcuts (e.g. Esc-to-quit while Esc means cancel-edit).
pub fn wantsKeyboard(self: *const Self) bool {
    var it = self.state_map.valueIterator();
    while (it.next()) |ws| switch (ws.*) {
        .text => |t| if (t.flags & WidgetState.focused != 0) return true,
        else => {},
    };
    return false;
}

/// Wire state pointers on every widget so rendering always works,
/// regardless of whether events were consumed.
/// TWO passes, and the split is load-bearing.
///
/// `getOrCreateState` calls `state_map.getOrPut`, which REHASHES when the map
/// grows — invalidating every `value_ptr` handed out earlier. Wiring pointers
/// as we walk means the first widgets' `state` pointers dangle the moment a
/// later insert triggers a rehash.
///
/// Pass 1 inserts every id (map stops growing). Pass 2 takes the pointers,
/// which are now stable. Before the `inline else` recursion this was masked:
/// only 4 container types recursed, so few ids were inserted and the map
/// rarely rehashed mid-walk.
fn wireState(self: *Self, node: *WidgetNode) void {
    ensureState(self, node);
    bindState(self, node);
}

/// Pass 1 — insert ids only. Discards the pointers on purpose.
fn ensureState(self: *Self, node: *WidgetNode) void {
    switch (node.widget) {
        inline else => |*w| {
            const W = @TypeOf(w.*);
            if (@hasField(W, "id") and @hasDecl(W, "state_kind")) {
                switch (W.state_kind) {
                    .flags => _ = self.getOrCreateState(w.id, .{ .flags = 0 }),
                    .value => _ = self.getOrCreateState(w.id, .{ .value = .{ .val = 0, .flags = 0 } }),
                    .cursor => _ = self.getOrCreateState(w.id, .{ .cursor = .{} }),
                    .text => _ = self.getOrCreateState(w.id, .{ .text = .{} }),
                    else => {},
                }
            }
        },
    }
    switch (node.widget) {
        inline else => |*w| {
            const W = @TypeOf(w.*);
            if (@hasDecl(W, "children"))
                for (w.children()) |*c| ensureState(self, c);
        },
    }
}

/// Pass 2 — take pointers. The map no longer grows, so these stay valid.
fn bindState(self: *Self, node: *WidgetNode) void {
    switch (node.widget) {
        inline else => |*w| {
            const W = @TypeOf(w.*);
            if (@hasField(W, "id") and @hasDecl(W, "state_kind")) {
                const kind = W.state_kind;
                switch (kind) {
                    .flags => {
                        if (self.state_map.getPtr(w.id)) |ws| w.state = &ws.flags;
                    },
                    .value => {
                        if (self.state_map.getPtr(w.id)) |ws| {
                            w.state_value = &ws.value.val;
                            w.state_flags = &ws.value.flags;
                        }
                    },
                    .cursor => {
                        if (self.state_map.getPtr(w.id)) |ws| w.state = ws;
                    },
                    .text => {
                        if (self.state_map.getPtr(w.id)) |ws| w.state = &ws.text;
                    },
                    else => {},
                }
            }
        },
    }

    switch (node.widget) {
        inline else => |*w| {
            const W = @TypeOf(w.*);
            if (@hasDecl(W, "children"))
                for (w.children()) |*c| bindState(self, c);
        },
    }
}

/// Unfocus every text field; whatever was focused is marked `changed`.
fn blurAll(self: *Self) void {
    var it = self.state_map.valueIterator();
    while (it.next()) |ws| switch (ws.*) {
        .text => |*t| if (t.flags & WidgetState.focused != 0) {
            t.flags &= ~WidgetState.focused;
            t.flags |= WidgetState.changed;
        },
        else => {},
    };
}

/// Clear the DRAGGING flag on every value-state widget.
fn clearAllDragging(self: *Self) void {
    var it = self.state_map.iterator();
    while (it.next()) |entry| {
        switch (entry.value_ptr.*) {
            .value => |*v| v.flags &= ~WidgetState.dragging,
            else => {},
        }
    }
}

fn dispatchEvent(node: *WidgetNode, event: *Event) void {
    if (event.consumed) return;
    switch (node.widget) {
        inline else => |*w| {
            const W = @TypeOf(w.*);
            if (@hasDecl(W, "handleEvent"))
                w.handleEvent(event, node.bounds);
        },
    }

    switch (node.widget) {
        inline else => |*w| {
            const W = @TypeOf(w.*);
            if (@hasDecl(W, "clips_children") and isPointerPress(event.kind) and
                !node.bounds.contains(event.mousePos())) return;
            if (@hasDecl(W, "children"))
                for (w.children()) |*c| dispatchEvent(c, event);
        },
    }
}

/// Clicks and wheel are position-targeted. mouse_move still passes so hover
/// clears when the cursor leaves; keys/text are focus-targeted.
fn isPointerPress(kind: EventKind) bool {
    return switch (kind) {
        .mouse_down, .mouse_up, .mouse_scroll => true,
        else => false,
    };
}
