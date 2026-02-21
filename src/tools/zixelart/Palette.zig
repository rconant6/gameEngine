const std = @import("std");
const Self = @This();
const rend = @import("renderer");
const Color = rend.Color;
const Colors = rend.Colors;
const Library = rend.ColorLibrary;
const gen = rend.Generator;
const log = @import("debug").log;
// const gradient = gen.gradient(Colors.IRIS_GREEN, Colors.AFTERNOON_BLUE, 9);
const cols1 = gen.gradient(Colors.BLACK, Colors.WHITE, 6);
const cols2 = gen.shades(Colors.RED, 6);
const cols3 = gen.shades(Colors.ORANGE, 6);
const cols4 = gen.shades(Colors.YELLOW, 6);
const cols5 = gen.shades(Colors.GREEN, 6);
const cols6 = gen.shades(Colors.CYAN, 6);
const cols7 = gen.shades(Colors.BLUE, 6);
const cols8 = gen.shades(Colors.MAGENTA, 6);

colors: [48]Color,

width: usize,
height: usize,
swatch_count: usize,
swatch_size: usize,

pub fn init(
    width: usize,
    height: usize,
    swatch_count: usize,
) Self {
    return .{
        .width = width,
        .height = height,
        .swatch_size = height / swatch_count,
        .colors = cols1 ++ cols2 ++ cols3 ++ cols4 ++ cols5 ++ cols6 ++ cols7 ++ cols8,
    };
}
pub fn print(self: *const Self) void {
    for (self.colors) |c| {
        // const tc = gen.snap(c, c.hue(), c.tone(), c.saturation());
        log.trace(
            .application,
            \\ r: {d:3} g: {d:3} b: {d:3}
            \\                      hue: {any} tone: {any} sat: {any}
            // \\ {s}
        ,
            .{
                c.rgba.r,
                c.rgba.g,
                c.rgba.a,
                c.hue(),
                c.tone(),
                c.saturation(),
                // tc.name,
            },
        );
    }
}
