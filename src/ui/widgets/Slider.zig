const assets = @import("assets");
const Font = assets.Font;
const rend = @import("renderer");
const Color = rend.Color;
const Colors = rend.Colors;
const ColorLibrary = rend.ColorLibrary;
const Renderer = rend.Renderer;
const RenderContext = rend.RenderContext;
const Size = l_out.Size;
const l_out = @import("../layout.zig");
const Constraints = l_out.Constraints;
const Rect = @import("../Rect.zig");
const evt = @import("../event.zig");
const Event = evt.Event;
const dbg = @import("debug");
const log = dbg.log;

const Self = @This();

pub const state_kind = .value;

id: []const u8,
min: f32,
max: f32,
track_color: Color,
thumb_color: Color,
fill_color: Color,
state_flags: ?*u16 = null,
state_value: ?*f16 = null,

const std = @import("std");

/// Ergonomic wrapper around the raw f16 value + u16 flags owned by UIManager.
/// Zero-cost at runtime — the compiler inlines everything.
pub const SliderState = struct {
    const DRAGGING: u16 = 0x4;

    val: *f16,
    flags: *u16,

    pub fn getValue(self: SliderState) f32 {
        return @floatCast(self.val.*);
    }
    pub fn setValue(self: SliderState, v: f32, min: f32, max: f32) void {
        self.val.* = @floatCast(std.math.clamp(v, min, max));
    }
    pub fn isDragging(self: SliderState) bool {
        return self.flags.* & DRAGGING != 0;
    }
    pub fn setDragging(self: SliderState, val: bool) void {
        if (val) self.flags.* |= DRAGGING else self.flags.* &= ~DRAGGING;
    }
};

pub fn layout(
    self: *Self,
    constraints: Constraints,
    origin_x: f32,
    origin_y: f32,
) Size {
    _ = self;
    _ = origin_x;
    _ = origin_y;
    return .{
        .width = constraints.max_width,
        .height = 24,
    };
}

pub fn handleEvent(self: *Self, event: *Event, bounds: Rect) void {
    if (event.consumed) return;

    const state = SliderState{
        .flags = self.state_flags orelse return,
        .val = self.state_value orelse return,
    };

    switch (event.kind) {
        .mouse_move => {
            if (state.isDragging()) {
                const normalized = std.math.clamp(
                    (event.mouse_x - bounds.x) / bounds.width,
                    0.0,
                    1.0,
                );
                state.setValue(self.min + normalized * (self.max - self.min), self.min, self.max);
                event.consume();
            }
        },
        .mouse_down => {
            const hit = bounds.contains(.{ .x = event.mouse_x, .y = event.mouse_y });
            if (hit) {
                state.setDragging(true);
                const normalized = std.math.clamp(
                    (event.mouse_x - bounds.x) / bounds.width,
                    0.0,
                    1.0,
                );
                state.setValue(self.min + normalized * (self.max - self.min), self.min, self.max);
                event.consume();
            }
        },
        .mouse_up => {
            if (state.isDragging()) {
                state.setDragging(false);
                event.consume();
            }
        },
    }
}

pub fn render(
    self: *const Self,
    renderer: *Renderer,
    font: *const Font,
    bounds: Rect,
    ctx: RenderContext,
) void {
    _ = font;
    const ScreenRect = rend.ShapeRegistry.getShapeType("RectangleScreen") orelse
        return;

    // Read current value, compute normalized position
    const state = SliderState{
        .val = self.state_value orelse return,
        .flags = self.state_flags orelse return,
    };
    const range = self.max - self.min;
    const normalized = if (range > 0) std.math.clamp(
        (state.getValue() - self.min) / range,
        0.0,
        1.0,
    ) else 0.0;
    const thumb_x = bounds.x + normalized * bounds.width;
    const track_y = bounds.y + (bounds.height - 4) / 2;

    // TRACK (full width, background)
    const track_shape = rend.ShapeRegistry.createShapeUnion(
        ScreenRect,
        ScreenRect.initFromTopLeft(
            .{ .x = bounds.x, .y = track_y },
            bounds.width,
            4,
        ),
    );
    renderer.drawGeometry(
        track_shape,
        null,
        self.track_color,
        null,
        1,
        ctx,
    );

    // FILL (from left edge to thumb position)
    if (normalized > 0) {
        const fill_shape = rend.ShapeRegistry.createShapeUnion(
            ScreenRect,
            ScreenRect.initFromTopLeft(
                .{ .x = bounds.x, .y = track_y },
                thumb_x - bounds.x,
                4,
            ),
        );
        renderer.drawGeometry(
            fill_shape,
            null,
            self.fill_color,
            null,
            1,
            ctx,
        );
    }

    // THUMB (vertical bar at value position)
    const thumb_shape = rend.ShapeRegistry.createShapeUnion(
        ScreenRect,
        ScreenRect.initFromTopLeft(
            .{ .x = thumb_x - 2, .y = bounds.y },
            4,
            bounds.height,
        ),
    );
    renderer.drawGeometry(
        thumb_shape,
        null,
        self.thumb_color,
        null,
        1,
        ctx,
    );
}
