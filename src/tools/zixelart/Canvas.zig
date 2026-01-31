const std = @import("std");
const rend = @import("renderer");
const ShapeData = rend.ShapeData;
const Color = rend.Color;
const Colors = rend.Colors;
const Self = @This();
const debug = @import("debug");
const log = debug.log;

pub const PixelCell = struct {
    shape: ShapeData,
    color: Color,
};

child_allocator: std.mem.Allocator,
arena: std.heap.ArenaAllocator,
allocator: std.mem.Allocator,

width: usize,
height: usize,
pixel_count: usize,
pixel_size: usize,
x_offset: usize,

pixels: []PixelCell = undefined,

pub fn init(
    child_alloc: std.mem.Allocator,
    width: usize,
    height: usize,
    pixel_count: usize,
) !*Self {
    const self = try child_alloc.create(Self);

    self.child_allocator = child_alloc;
    self.arena = std.heap.ArenaAllocator.init(child_alloc);
    self.allocator = self.arena.allocator();

    self.width = width;
    self.height = height;
    self.pixel_count = pixel_count;
    self.pixel_size = height / pixel_count;
    self.x_offset = (width - height) / 2;

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
            const loc_y = j * self.pixel_size + self.pixel_size / 2;
            self.pixels[j * pixel_count + i] = .{
                .shape = rend.ShapeRegistry.createShapeUnion(
                    ScreenRect,
                    ScreenRect.initSquare(
                        .{ .x = @intCast(loc_x), .y = @intCast(loc_y) },
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
    self.child_allocator.destroy(self);
}
pub fn setPixel(self: *Self, x: usize, y: usize, color: Color) void {
    self.pixels[y * self.pixel_count + x].color = color;
}
pub fn clear(self: *Self) void {
    for (self.pixels) |*pixel| {
        pixel.color = Colors.LIGHT_GRAY;
    }
}
