/// NOTE: This is a hard coded mess (snuffalagus this up!)
/// Screen space: Y=0 is TOP of screen, Y increases downward
const screen_width: f32 = 1920;
const screen_height: f32 = 1088;
const info_bar_height: f32 = 40;
const right_panel_width: f32 = 300;
const toolbar_width: f32 = 240;

const content_top: f32 = 0; // Top of content area (below nothing, starts at top)
const content_height = screen_height - info_bar_height;
const canvas_area_width = screen_width - toolbar_width - right_panel_width;
const canvas_size = @min(canvas_area_width, content_height);
const canvas_x_offset = toolbar_width + (canvas_area_width - canvas_size) / 2;
const pixel_size = canvas_size / 64;

pub const Region = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

pub const toolbar: Region = .{
    .x = 0,
    .y = content_top,
    .width = toolbar_width,
    .height = content_height,
};
pub const canvas: Region = .{
    .x = canvas_x_offset,
    .y = content_top,
    .width = canvas_area_width,
    .height = content_height,
};
pub const palette: Region = .{
    .x = screen_width - right_panel_width,
    .y = content_top,
    .width = right_panel_width,
    .height = 400,
};
pub const shades: Region = .{
    .x = screen_width - right_panel_width,
    .y = content_top + 400,
    .width = right_panel_width,
    .height = 300,
};
pub const preview: Region = .{
    .x = screen_width - right_panel_width,
    .y = content_top + 700,
    .width = right_panel_width,
    .height = content_height - 700,
};
pub const info_bar: Region = .{
    .x = 0,
    .y = screen_height - info_bar_height, // Bottom of screen
    .width = screen_width,
    .height = info_bar_height,
};
