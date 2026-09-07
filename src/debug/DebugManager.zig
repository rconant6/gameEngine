const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Self = @This();
const d_draw = @import("DebugDraw.zig");
const DebugDraw = d_draw.DebugDraw;
const DebugCategory = d_draw.DebugCategory;
const DebugCategoryEnum = d_draw.DebugCategoryEnum;
const DebugText = d_draw.DebugText;
const DebugRenderer = @import("DebugRenderer.zig");
const rend = @import("renderer");
const Renderer = rend.Renderer;
const Texture = Renderer.Texture;
const Colors = rend.Colors;
const Color = rend.Color;
const math = @import("math");
const V2 = math.V2;
const assets = @import("assets");
const Font = assets.Font;

const TimedText = struct {
    text: []u8, // persistent-allocated, freed on expiry
    position: V2,
    color: Color,
    size: f32,
    duration: f32, // remaining seconds, always > 0 on creation
    cat: DebugCategory,
};

frame: Allocator,
persistent: Allocator,
timed_texts: ArrayList(TimedText),
draw: DebugDraw,
renderer: DebugRenderer,

pub fn init(
    frame: Allocator,
    persistent: Allocator,
    renderer: *Renderer,
    default_font: *const Font,
    default_tex: *Texture,
) Self {
    return .{
        .frame = frame,
        .persistent = persistent,
        .timed_texts = .empty,
        .draw = .init(frame, persistent),
        .renderer = .init(renderer, default_font, default_tex),
    };
}

pub fn beginFrame(self: *Self) void {
    // frame arena was just reset by tickFrame — reinit texts from the new frame allocator
    // rather than retaining capacity (which would hold a dangling pointer into the old arena)
    self.draw.texts = .empty;
}

pub fn deinit(self: *Self) void {
    for (self.timed_texts.items) |t| self.persistent.free(t.text);
    self.timed_texts.deinit(self.persistent);
    self.draw.deinit();
}

pub fn toggleCategory(self: *Self, category: DebugCategoryEnum) void {
    var cat_name: []const u8 = undefined;
    var is_enabled: bool = undefined;

    switch (category) {
        .collision => {
            self.draw.visible_categories.bits.collision = !self.draw.visible_categories.bits.collision;
            cat_name = "Collision";
            is_enabled = self.draw.visible_categories.bits.collision;
        },
        .velocity => {
            self.draw.visible_categories.bits.velocity = !self.draw.visible_categories.bits.velocity;
            cat_name = "Velocity";
            is_enabled = self.draw.visible_categories.bits.velocity;
        },
        .entity_info => {
            self.draw.visible_categories.bits.entity_info = !self.draw.visible_categories.bits.entity_info;
            cat_name = "Entity Info";
            is_enabled = self.draw.visible_categories.bits.entity_info;
        },
        .grid => {
            self.draw.visible_categories.bits.grid = !self.draw.visible_categories.bits.grid;
            cat_name = "Grid";
            is_enabled = self.draw.visible_categories.bits.grid;
        },
        .fps => {
            self.draw.visible_categories.bits.fps = !self.draw.visible_categories.bits.fps;
            cat_name = "FPS";
            is_enabled = self.draw.visible_categories.bits.fps;
        },
        .custom => {
            self.draw.visible_categories.bits.custom = !self.draw.visible_categories.bits.custom;
            cat_name = "Custom";
            is_enabled = self.draw.visible_categories.bits.custom;
        },
    }

    const status = if (is_enabled) "ON" else "OFF";
    const color = if (is_enabled) Colors.GREEN else Colors.RED;
    const message = std.fmt.allocPrint(
        self.persistent,
        "{s}: {s}",
        .{ cat_name, status },
    ) catch return;

    self.timed_texts.append(self.persistent, .{
        .text = message,
        .position = .{ .x = 10, .y = 8 },
        .color = color,
        .size = 0.25,
        .duration = 1.5,
        .cat = DebugCategory.single(.custom),
    }) catch {
        self.persistent.free(message);
    };
}

pub fn run(self: *Self, dt: f32, ctx: anytype) void {
    // tick timed entries, push survivors as borrows into draw.texts this frame
    var i: usize = 0;
    while (i < self.timed_texts.items.len) {
        var t = &self.timed_texts.items[i];
        t.duration -= dt;
        if (t.duration <= 0) {
            self.persistent.free(t.text);
            _ = self.timed_texts.swapRemove(i);
            continue;
        }
        // still alive — borrow the slice into draw.texts for this frame
        self.draw.addText(.{
            .text = t.text,
            .position = t.position,
            .color = t.color,
            .size = t.size,
            .cat = t.cat,
        });
        i += 1;
    }
    self.renderer.render(&self.draw, ctx);
    self.draw.update(dt);
}
