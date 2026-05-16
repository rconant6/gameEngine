const myvk = @import("types.zig");
const Instance = myvk.Instance;
const Surface = myvk.Surface;
const PhysicalDevice = myvk.PhysicalDevice;

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const RenderContext = @import("../../RenderContext.zig");
const rend = @import("../../renderer.zig");
const RenderConfig = rend.RendererConfig;
const Color = rend.Color;
const ShapeData = rend.ShapeData;
const Transform = rend.Transform;

const WaylandHandles = struct {
    display: *anyopaque,
    surface: *anyopaque,
};

const Self = @This();

pub const Texture = struct {};

gpa: Allocator,
instance: Instance,
// surface: Surface,
gpu: PhysicalDevice,
// device: vk.VkDevice,
// queue: vk.VkQueue,

pub fn init(
    alloc: std.mem.Allocator,
    io: std.Io,
    config: RenderConfig,
) !Self {
    const handles: *WaylandHandles =
        @as(*WaylandHandles, @ptrCast(@alignCast(config.native_handle)));

    // TODO: Comeback and deal w/ validation layers
    const instance = try Instance.init();
    // const surface = try Surface.init();
    const phys_device = try PhysicalDevice.init(instance.handle);

    _ = io;
    _ = handles;

    return .{
        .gpa = alloc,
        .instance = instance,
        .gpu = phys_device,
        // .surface = surface,
    };
}

pub fn deinit(self: *Self) void {
    self.instance.deinit();
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
}
pub fn endFrame(self: *Self) !void {
    _ = self;
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
