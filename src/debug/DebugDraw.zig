const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const core = @import("core");
const V2 = core.V2;
const render = @import("renderer");
const Color = render.Color;
const Colors = render.Colors;

pub const Indefinate = std.math.inf(f32);
pub const DebugCategory = packed struct {
    collision: bool = false,
    velocity: bool = false,
    entity_info: bool = false,
    grid: bool = false,
    fps: bool = false,
    custom: bool = false,
    padding: u2 = 0,

    pub const none = DebugCategory{};
    pub const all = DebugCategory{
        .collision = true,
        .velocity = true,
        .entity_info = true,
        .grid = true,
        .fps = true,
        .custom = true,
    };
    pub const entity = DebugCategory{
        .collision = true,
        .velocity = true,
        .entity_info = true,
    };

    pub fn matches(self: DebugCategory, filter: DebugCategory) bool {
        const self_bits = @as(u8, @bitCast(self));
        const filter_bits = @as(u8, @bitCast(filter));
        return (self_bits & filter_bits) != 0;
    }
};

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
        updateShapeList(&self.texts, dt);
        // TODO: deal w/ frame time
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

            shape.duration.? -= dt;

            if (shape.duration.? <= 0) {
                _ = list.swapRemove(i);
                continue;
            }

            i += 1;
        }
    }

    pub fn toggleCategory(self: *DebugDraw, category: DebugCategory) void {
        if (category.collision) self.visible_categories.collision = !self.visible_categories.collision;
        if (category.velocity) self.visible_categories.velocity = !self.visible_categories.velocity;
        if (category.entity_info) self.visible_categories.entity_info = !self.visible_categories.entity_info;
        if (category.grid) self.visible_categories.grid = !self.visible_categories.grid;
        if (category.fps) self.visible_categories.fps = !self.visible_categories.fps;
        if (category.custom) self.visible_categories.custom = !self.visible_categories.custom;
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

    pub fn addArrow(self: *DebugDraw, arrow: DebugArrow) !void {
        try self.arrows.append(self.gpa, arrow);
    }
    pub fn addCircle(self: *DebugDraw, circle: DebugCircle) !void {
        try self.circles.append(self.gpa, circle);
    }
    pub fn addLine(self: *DebugDraw, line: DebugLine) !void {
        try self.lines.append(self.gpa, line);
    }
    pub fn addRect(self: *DebugDraw, rect: DebugRect) !void {
        try self.rects.append(self.gpa, rect);
    }
    pub fn addText(self: *DebugDraw, text: DebugText) !void {
        try self.texts.append(self.gpa, text);
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
            self.gpa.free(ts.text);
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
};
