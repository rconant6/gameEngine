const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const math = @import("math");
const V2 = math.V2;
const render = @import("renderer");
const Color = render.Color;
const Colors = render.Colors;
const log = @import("log.zig");

pub const Indefinate = std.math.inf(f32);
// NOTE: This is the 'registry' for the debugger
pub const DebugCategoryEnum = enum {
    collision,
    velocity,
    entity_info,
    grid,
    fps,
    custom,
};
pub const DebugCategory = GenerateDebugCategory(DebugCategoryEnum);

fn GenerateDebugCategory(comptime CategoryEnum: type) type {
    const enum_info = @typeInfo(CategoryEnum).@"enum";
    const field_count = enum_info.fields.len;
    const padding_bits = (8 - (field_count % 8)) % 8;

    const total_fields = field_count + (if (padding_bits > 0) 1 else 0);
    var field_names: [total_fields][]const u8 = undefined;
    var field_types: [total_fields]type = undefined;
    var field_attrs: [total_fields]std.builtin.Type.StructField.Attributes = undefined;

    const true_val: bool = true;
    for (enum_info.fields, 0..) |enum_field, i| {
        field_names[i] = enum_field.name;
        field_types[i] = bool;
        field_attrs[i] = .{ .default_value_ptr = &true_val };
    }

    if (padding_bits > 0) {
        const PaddingType = @Int(.unsigned, padding_bits);
        const zero_val: PaddingType = 0;
        field_names[field_count] = "padding";
        field_types[field_count] = PaddingType;
        field_attrs[field_count] = .{ .default_value_ptr = &zero_val };
    }

    const PackedStruct = @Struct(
        .@"packed",
        null,
        &field_names,
        &field_types,
        &field_attrs,
    );

    return struct {
        bits: PackedStruct,
        const Self = @This();

        pub fn single(cat_type: CategoryEnum) Self {
            var result = Self{ .bits = .{
                .collision = false,
                .velocity = false,
                .entity_info = false,
                .grid = false,
                .fps = false,
                .custom = false,
            } };
            switch (cat_type) {
                .collision => result.bits.collision = true,
                .velocity => result.bits.velocity = true,
                .entity_info => result.bits.entity_info = true,
                .grid => result.bits.grid = true,
                .fps => result.bits.fps = true,
                .custom => result.bits.custom = true,
            }
            return result;
        }

        pub const none = Self{ .bits = .{
            .collision = false,
            .velocity = false,
            .entity_info = false,
            .grid = false,
            .fps = false,
            .custom = false,
        } };
        pub const all = Self{ .bits = .{
            .collision = true,
            .velocity = true,
            .entity_info = true,
            .grid = true,
            .fps = true,
            .custom = true,
        } };
        pub fn format(self: Self, w: *std.Io.Writer) !void {
            try w.print(
                \\Visible:
                \\      collision {}
                \\      velocity {}
                \\      entity_info {}
                \\      grid {}
                \\      fps {}
                \\      custom {} 
                \\      padding
            , .{
                self.visible_categories.bits.collision,
                self.visible_categories.bits.velocity,
                self.visible_categories.bits.entity_info,
                self.visible_categories.bits.grid,
                self.visible_categories.bits.fps,
                self.visible_categories.bits.custom,
            });
        }
        pub fn matches(self: Self, filter: Self) bool {
            const self_bits = @as(u8, @bitCast(self.bits));
            const filter_bits = @as(u8, @bitCast(filter.bits));
            return (self_bits & filter_bits) != 0;
        }
    };
}

pub const DebugDraw = struct {
    frame: Allocator,      // texts list backing, cleared each frame
    persistent: Allocator, // shape list backing, survives frame arena reset
    arrows: ArrayList(DebugArrow),
    circles: ArrayList(DebugCircle),
    lines: ArrayList(DebugLine),
    rects: ArrayList(DebugRect),
    texts: ArrayList(DebugText),
    frame_time: f32,
    visible_categories: DebugCategory = .all,

    pub fn update(self: *DebugDraw, dt: f32) void {
        updateShapeList(&self.arrows, dt);
        updateShapeList(&self.circles, dt);
        updateShapeList(&self.lines, dt);
        updateShapeList(&self.rects, dt);
        updateTextList(self);
    }
    fn updateShapeList(list: anytype, dt: f32) void {
        var i: usize = 0;
        while (i < list.items.len) {
            var shape = &list.items[i];

            if (shape.duration == null) {
                _ = list.swapRemove(i);
                continue;
            }

            if (std.math.isInf(shape.duration.?)) {
                i += 1;
                continue;
            }

            shape.duration = shape.duration.? - dt;

            if (shape.duration.? <= 0) {
                _ = list.swapRemove(i);
                continue;
            }

            i += 1;
        }
    }

    fn updateTextList(self: *DebugDraw) void {
        clearFrameList(&self.texts, self.frame);
    }

    pub fn clear(self: *DebugDraw) void {
        // Shape lists are persistent-backed: that memory survives the frame arena
        // reset, so retaining capacity is valid and cheap.
        self.arrows.clearRetainingCapacity();
        self.circles.clearRetainingCapacity();
        self.lines.clearRetainingCapacity();
        self.rects.clearRetainingCapacity();
        // texts is frame-backed (per-frame arena, reset every frame). Retaining
        // capacity would dangle into reclaimed memory and alias on the next grow
        // (@memcpy panic in Debug, silent UB in release) — same bug as
        // ActionQueue. Free + reset to empty so it re-grows fresh each frame.
        clearFrameList(&self.texts, self.frame);
    }

    // Drop a frame-arena-backed list's buffer entirely (free keeps real allocators
    // leak-clean; .empty drops the stale pointer that would alias post-reset).
    fn clearFrameList(list: anytype, frame: Allocator) void {
        list.deinit(frame);
        list.* = .empty;
    }
    pub fn clearCategory(self: *DebugDraw, cat: DebugCategory) void {
        clearCategoryFromList(self.arrows, cat);
        clearCategoryFromList(self.circles, cat);
        clearCategoryFromList(self.lines, cat);
        clearCategoryFromList(self.rects, cat);
        clearCategoryFromList(self.texts, cat);
    }
    fn clearCategoryFromList(list: anytype, category: DebugCategory) void {
        var i: usize = 0;
        while (i < list.items.len) {
            if (list.items[i].cat.matches(category)) {
                _ = list.swapRemove(i);
            } else {
                i += 1;
            }
        }
    }

    pub fn addArrow(self: *DebugDraw, arrow: DebugArrow) void {
        self.arrows.append(self.persistent, arrow) catch {};
    }
    pub fn addCircle(self: *DebugDraw, circle: DebugCircle) void {
        self.circles.append(self.persistent, circle) catch {};
    }
    pub fn addLine(self: *DebugDraw, line: DebugLine) void {
        self.lines.append(self.persistent, line) catch {};
    }
    pub fn addRect(self: *DebugDraw, rect: DebugRect) void {
        self.rects.append(self.persistent, rect) catch {};
    }
    pub fn addText(self: *DebugDraw, text: DebugText) void {
        self.texts.append(self.frame, text) catch {};
    }

    pub fn init(frame: Allocator, persistent: Allocator) DebugDraw {
        return .{
            .frame = frame,
            .persistent = persistent,
            .arrows = .empty,
            .circles = .empty,
            .lines = .empty,
            .rects = .empty,
            .texts = .empty,
            .frame_time = 0,
        };
    }

    pub fn deinit(self: *DebugDraw) void {
        self.arrows.deinit(self.persistent);
        self.circles.deinit(self.persistent);
        self.lines.deinit(self.persistent);
        self.rects.deinit(self.persistent);
        // texts is frame-backed and always reinit'd each beginFrame — no deinit needed
    }
};

pub const DebugArrow = struct {
    start: V2,
    end: V2,
    color: Color,
    head_size: f32,
    duration: ?f32 = null,
    cat: DebugCategory,
};
pub const DebugCircle = struct {
    origin: V2,
    radius: f32,
    color: Color,
    filled: bool = false,
    duration: ?f32 = null,
    cat: DebugCategory,
};

pub const DebugLine = struct {
    start: V2,
    end: V2,
    color: Color,
    duration: ?f32 = null,
    cat: DebugCategory,
};

pub const DebugRect = struct {
    min: V2,
    max: V2,
    color: Color,
    rotation: ?f32 = null,
    filled: bool = false,
    duration: ?f32 = null,
    cat: DebugCategory,
};

pub const DebugText = struct {
    text: []const u8,
    position: V2,
    color: Color,
    size: f32,
    cat: DebugCategory,
};
