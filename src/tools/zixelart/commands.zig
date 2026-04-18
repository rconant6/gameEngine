const Tool = @import("tool.zig").Tool;
const rend = @import("renderer");
const Color = rend.Color;
const Canvas = @import("Canvas.zig");

pub const ToolCommand = struct {
    kind: Tool,
    pixels: []PixelChange,

    pub fn undo(self: ToolCommand, canvas: *Canvas) void {
        for (self.pixels) |px| {
            const idx = px.y * canvas.pixel_count + px.x;
            canvas.pixels[idx].color = px.old_color orelse canvas.blank_color;
        }
    }
    pub fn redo(self: ToolCommand, canvas: *Canvas) void {
        for (self.pixels) |px| {
            const idx = px.y * canvas.pixel_count + px.x;
            canvas.pixels[idx].color = px.new_color orelse canvas.blank_color;
        }
    }
};

pub const PixelChange = struct {
    x: usize,
    y: usize,
    old_color: ?Color,
    new_color: ?Color,
};
