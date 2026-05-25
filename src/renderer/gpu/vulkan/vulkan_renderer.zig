const myvk = @import("types.zig");
const Instance = myvk.Instance;
const Surface = myvk.Surface;
const PhysicalDevice = myvk.PhysicalDevice;
const Device = myvk.Device;
const Swapchain = myvk.Swapchain;
const RenderPass = myvk.RenderPass;
const Framebuffer = myvk.Framebuffer;
const vk = @import("c_bridge.zig").c;

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

gpa: Allocator,
instance: Instance,
surface: Surface,
gpu: PhysicalDevice,
dev: Device,
sc: Swapchain,
rp: RenderPass,
fb: []vk.VkFramebuffer,

pub fn init(
    alloc: std.mem.Allocator,
    _: std.Io,
    config: RenderConfig,
) !Self {
    const native_handle = config.native_handle orelse return error.MissingNativeHandle;

    // TODO: Comeback and deal w/ validation layers
    const instance = try Instance.init();
    const surface = try Surface.init(
        instance.handle,
        native_handle,
    );
    const phys_device = try PhysicalDevice.init(
        alloc,
        instance.handle,
        surface.handle,
    );
    const dev = try Device.init(&phys_device);
    const swapchain = try Swapchain.init(
        alloc,
        dev,
        phys_device,
        surface,
        config.width,
        config.height,
    );
    const render_pass = try RenderPass.init(dev, swapchain.format);

    const framebuffers = try Framebuffer.init(
        alloc,
        dev,
        render_pass,
        swapchain.views,
        swapchain.extent,
    );

    return .{
        .gpa = alloc,
        .instance = instance,
        .surface = surface,
        .gpu = phys_device,
        .dev = dev,
        .sc = swapchain,
        .rp = render_pass,
        .fb = framebuffers,
    };
}

pub fn deinit(self: *Self) void {
    Framebuffer.deinit(self.gpa, self.dev, self.fb);
    self.rp.deinit(self.dev);
    self.sc.deinit(self.dev);
    self.dev.deinit();
    self.gpu.deinit();
    self.surface.deinit(self.instance.handle);
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
