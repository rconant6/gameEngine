const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const core = @import("core");
const V2 = core.V2;
const render = @import("renderer");
const Color = render.Color;
const Colors = render.Colors;

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

    var fields: [field_count + (if (padding_bits > 0) 1 else 0)]std.builtin.Type.StructField = undefined;

    for (enum_info.fields, 0..) |enum_field, i| {
        fields[i] = .{
            .name = enum_field.name,
            .type = bool,
            .default_value_ptr = &true,
            .is_comptime = false,
            .alignment = 0,
        };
    }

    if (padding_bits > 0) {
        const PaddingType = @Type(.{ .int = .{
            .signedness = .unsigned,
            .bits = padding_bits,
        } });
        fields[field_count] = .{
            .name = "padding",
            .type = PaddingType,
            .default_value_ptr = &@as(PaddingType, 0),
            .is_comptime = false,
            .alignment = 0,
        };
    }

    const PackedStruct = @Type(.{ .@"struct" = .{
        .layout = .@"packed",
        .fields = &fields,
        .decls = &.{},
        .is_tuple = false,
    } });

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
    gpa: Allocator,
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
        updateTextList(self, dt);
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

    fn updateTextList(self: *DebugDraw, dt: f32) void {
        var i: usize = 0;
        while (i < self.texts.items.len) {
            var text = &self.texts.items[i];

            if (text.duration == null) {
                if (text.owns_text) self.gpa.free(text.text);
                _ = self.texts.swapRemove(i);
                continue;
            }

            if (std.math.isInf(text.duration.?)) {
                i += 1;
                continue;
            }

            text.duration = text.duration.? - dt;

            if (text.duration.? <= 0) {
                if (text.owns_text) self.gpa.free(text.text);
                _ = self.texts.swapRemove(i);
                continue;
            }

            i += 1;
        }
    }

    pub fn toggleCategory(self: *DebugDraw, category: DebugCategoryEnum) void {
        var cat_name: []const u8 = undefined;
        var is_enabled: bool = undefined;

        if (category == .collision) {
            self.visible_categories.bits.collision = !self.visible_categories.bits.collision;
            cat_name = "Collision";
            is_enabled = self.visible_categories.bits.collision;
        } else if (category == .velocity) {
            self.visible_categories.bits.velocity = !self.visible_categories.bits.velocity;
            cat_name = "Velocity";
            is_enabled = self.visible_categories.bits.velocity;
        } else if (category == .entity_info) {
            self.visible_categories.bits.entity_info = !self.visible_categories.bits.entity_info;
            cat_name = "Entity Info";
            is_enabled = self.visible_categories.bits.entity_info;
        } else if (category == .grid) {
            self.visible_categories.bits.grid = !self.visible_categories.bits.grid;
            cat_name = "Grid";
            is_enabled = self.visible_categories.bits.grid;
        } else if (category == .fps) {
            self.visible_categories.bits.fps = !self.visible_categories.bits.fps;
            cat_name = "FPS";
            is_enabled = self.visible_categories.bits.fps;
        } else if (category == .custom) {
            self.visible_categories.bits.custom = !self.visible_categories.bits.custom;
            cat_name = "Custom";
            is_enabled = self.visible_categories.bits.custom;
        } else {
            return;
        }

        // Create notification message
        const status = if (is_enabled) "ON" else "OFF";
        const color = if (is_enabled) Colors.GREEN else Colors.RED;

        const message = std.fmt.allocPrint(
            self.gpa,
            "{s}: {s}",
            .{ cat_name, status },
        ) catch return;

        self.addText(.{
            .text = message,
            .position = .{ .x = 10, .y = 8 },
            .color = color,
            .size = 0.25,
            .duration = 1.5,
            .cat = DebugCategory.single(.custom),
            .owns_text = true,
        });
        // }) catch {
        //     self.gpa.free(message);
        // };
    }
    pub fn clear(self: *DebugDraw) void {
        self.arrows.clearRetainingCapacity();
        self.circles.clearRetainingCapacity();
        self.lines.clearRetainingCapacity();
        self.rects.clearRetainingCapacity();
        self.texts.clearRetainingCapacity();
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
        self.arrows.append(self.gpa, arrow) catch {};
    }
    pub fn addCircle(self: *DebugDraw, circle: DebugCircle) void {
        self.circles.append(self.gpa, circle) catch {};
    }
    pub fn addLine(self: *DebugDraw, line: DebugLine) void {
        self.lines.append(self.gpa, line) catch {};
    }
    pub fn addRect(self: *DebugDraw, rect: DebugRect) void {
        self.rects.append(self.gpa, rect) catch {};
    }
    pub fn addText(self: *DebugDraw, text: DebugText) void {
        self.texts.append(self.gpa, text) catch {};
    }

    pub fn init(allocator: Allocator) DebugDraw {
        return .{
            .gpa = allocator,
            .arrows = .empty,
            .circles = .empty,
            .lines = .empty,
            .rects = .empty,
            .texts = .empty,
            .frame_time = 0,
        };
    }

    pub fn deinit(self: *DebugDraw) void {
        self.arrows.deinit(self.gpa);
        self.circles.deinit(self.gpa);
        self.lines.deinit(self.gpa);
        self.rects.deinit(self.gpa);
        for (self.texts.items) |*ts| {
            if (ts.owns_text) {
                self.gpa.free(ts.text);
            }
        }
        self.texts.deinit(self.gpa);
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
    duration: ?f32 = null,
    cat: DebugCategory,
    owns_text: bool = false,
};
