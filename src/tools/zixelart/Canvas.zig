const std = @import("std");
const rend = @import("renderer");
const ShapeData = rend.ShapeData;
const Color = rend.Color;
const Colors = rend.Colors;
const Self = @This();
const log = @import("debug").log;
const ZixelState = @import("ZixelState.zig");
const layout = @import("Layout.zig");
const Region = layout.Region;
const cmds = @import("commands.zig");
const PixelChange = cmds.PixelChange;
const ToolCommand = cmds.ToolCommand;
const CommandHistory = @import("CommandHistory.zig").CommandHistory;
const ToolDispatcher = @import("ToolFns.zig").ToolDispatcher;
const Tool = @import("tool.zig").Tool;

pub const PixelCell = struct {
    shape: ShapeData,
    color: Color,
};

gpa: std.mem.Allocator,
arena: std.heap.ArenaAllocator,
allocator: std.mem.Allocator,

width: usize,
height: usize,
pixel_count: usize,
pixel_size: usize,
x_offset: usize,
y_offset: usize,
blank_color: Color = Colors.CLEAR,

pixels: []PixelCell = undefined,

changes: std.ArrayList(PixelChange),
history: CommandHistory(ToolCommand),
dispatcher: ToolDispatcher,

pub fn init(
    child_alloc: std.mem.Allocator,
    region: Region,
    pixel_count: usize,
) !*Self {
    const self = try child_alloc.create(Self);

    self.gpa = child_alloc;

    self.arena = std.heap.ArenaAllocator.init(child_alloc);
    self.allocator = self.arena.allocator();

    self.changes = try .initCapacity(self.allocator, 48);
    self.history = .init(self.allocator);
    self.dispatcher = .init();

    self.width = @intFromFloat(region.width);
    self.height = @intFromFloat(region.height);
    self.pixel_count = pixel_count;
    self.pixel_size = @intFromFloat(region.height / @as(f32, @floatFromInt(pixel_count)));
    self.x_offset = @intFromFloat(region.x);
    self.y_offset = @intFromFloat(region.y);
    self.blank_color = Colors.LIGHT_GRAY;

    self.pixels = try self.allocator.alloc(PixelCell, pixel_count * pixel_count);

    const ScreenRect = rend.ShapeRegistry.getShapeType("RectangleScreen") orelse {
        log.err(.application, "Canvas works with Screen Rectangles only", .{});
        return error.InvalidCanvasShape;
    };
    var i: usize = 0;
    var j: usize = 0;
    while (i < pixel_count) : (i += 1) {
        while (j < pixel_count) : (j += 1) {
            const loc_x = i * self.pixel_size + self.x_offset + self.pixel_size / 2;
            const loc_y = j * self.pixel_size + self.y_offset + self.pixel_size / 2;
            self.pixels[j * pixel_count + i] = .{
                .shape = rend.ShapeRegistry.createShapeUnion(
                    ScreenRect,
                    ScreenRect.initSquare(
                        .{ .x = @floatFromInt(loc_x), .y = @floatFromInt(loc_y) },
                        @floatFromInt(self.pixel_size),
                    ),
                ),
                .color = Colors.LIGHT_GRAY,
            };
        }
        j = 0;
    }

    return self;
}
pub fn deinit(self: *Self) void {
    self.arena.deinit();
    self.gpa.destroy(self);
}
pub fn setPixel(self: *Self, state: *const ZixelState) void {
    self.pixels[
        state.cursor_y.? * self.pixel_count + state.cursor_x.?
    ].color = state.active_color;
}
pub fn clearPixel(self: *Self, state: *const ZixelState) void {
    self.pixels[
        state.cursor_y.? * self.pixel_count + state.cursor_x.?
    ].color = self.blank_color;
}
pub fn clear(self: *Self) void {
    for (self.pixels) |*pixel| {
        pixel.color = self.blank_color;
    }
}

// MARK: Tool related stuff
pub fn cancel(self: *Self) void {
    for (self.changes.items) |change| {
        const idx = change.y * self.pixel_count + change.x;
        self.pixels[idx].color = change.old_color orelse self.blank_color;
    }
}

pub fn onMouseDown(self: *Self, tool: Tool, x: usize, y: usize, color: Color) void {
    self.dispatcher.begin(tool, self, x, y, color);
}
pub fn onMouseUp(self: *Self, tool: Tool) void {
    if (self.dispatcher.commit(tool, self)) |cmd| {
        self.history.push(cmd);
    }
}
pub fn onCancel(self: *Self, tool: Tool) void {
    self.dispatcher.cancel(tool, self);
}
pub fn onMouseDrag(self: *Self, tool: Tool, x: usize, y: usize, color: Color) void {
    self.dispatcher.update(tool, self, x, y, color);
}
