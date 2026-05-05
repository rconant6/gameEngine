const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const RenderContext = @import("../../RenderContext.zig");
const rend = @import("../../renderer.zig");
const RenderConfig = rend.RendererConfig;
const Color = rend.Color;
const ShapeData = rend.ShapeData;
const Transform = rend.Transform;

const Self = @This();

pub const Texture = struct {};

pub fn init(gpa: std.mem.Allocator, io: std.Io, config: RenderConfig) !Self {
    _ = gpa;
    _ = io;
    _ = config;
    return error.NotImplemented;
}
pub fn deinit(self: *Self) void {
    _ = self;
}

pub fn clear(self: Self) void {
    _ = self;
}
pub fn setClearColor(self: *Self, color: Color) void {
    _ = self;
    _ = color;
}

pub fn beginFrame(self: *Self) !void {
    _ = self;
    return error.NotImplemented;
}
pub fn endFrame(self: *Self) !void {
    _ = self;
    return error.NotImplemented;
}

pub fn drawShape(
    self: *Self,
    shape: ShapeData,
    transform: ?Transform,
    fill_color: ?Color,
    stroke_color: ?Color,
    stroke_width: f32,
    ctx: RenderContext,
) void {
    _ = self;
    _ = shape;
    _ = transform;
    _ = fill_color;
    _ = stroke_color;
    _ = stroke_width;
    _ = ctx;
}

pub fn createTexture(self: *Self, width: u32, height: u32) !*Texture {
    _ = self;
    _ = width;
    _ = height;
    return error.NotImplemented;
}

pub fn uploadTextureData(
    _: *Self,
    texture: *Texture,
    width: u32,
    height: u32,
    data: [*]const u8,
    bytes_per_row: u32,
) void {
    _ = texture;
    _ = width;
    _ = height;
    _ = data;
    _ = bytes_per_row;
}
pub fn drawTextureQuad(
    self: *Self,
    texture: *Texture,
    // position: WorldPoint, // center position in world space
    width: f32, // world-space width
    height: f32, // world-space height
    origin: [2]f32, // normalized origin [0-1, 0-1] within the sprite
    transform: ?Transform, // scale/rotate/translate
    ctx: RenderContext,
    flip_h: bool,
    flip_v: bool,
) void {
    _ = self;
    _ = texture;
    _ = width; // world-space width
    _ = height; // world-space height
    _ = origin; // normalized origin [0-1, 0-1] within the sprite
    _ = transform; // scale/rotate/translate
    _ = ctx;
    _ = flip_h;
    _ = flip_v;
}
