const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const vk = @import("c_bridge.zig").c;
const myvk = @import("types.zig");
const frames_in_flight = myvk.frames_in_flight;
const CommandPool = myvk.CommandPool;
const Device = myvk.Device;
const Framebuffer = myvk.Framebuffer;
const Instance = myvk.Instance;
const PhysicalDevice = myvk.PhysicalDevice;
const RenderPass = myvk.RenderPass;
const Surface = myvk.Surface;
const Swapchain = myvk.Swapchain;
const Sync = myvk.Sync;
const FrameSync = myvk.FrameSync;
const RenderContext = @import("../../RenderContext.zig");
const rend = @import("../../renderer.zig");
const RenderConfig = rend.RendererConfig;
const Color = rend.Color;
const ShapeData = rend.ShapeData;
const Transform = rend.Transform;
const log = @import("debug").log;

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
cmd: CommandPool,
syncs: [frames_in_flight]FrameSync,
render_finished: []vk.VkSemaphore,

clear_color: vk.VkClearColorValue = .{ .float32 = .{ 1, 0, 0, 1 } }, // pink?
current_frame: u32 = 0,
current_image: u32 = 0,

pub fn init(
    alloc: std.mem.Allocator,
    _: std.Io,
    config: RenderConfig,
) !Self {
    const native_handle = config.native_handle orelse return error.MissingNativeHandle;

    const WaylandHandles = extern struct { display: *anyopaque, surface: *anyopaque, drm_device: u64 };
    const drm_device = @as(*WaylandHandles, @ptrCast(@alignCast(native_handle))).drm_device;

    const instance = try Instance.init();
    const surface = try Surface.init(
        instance.handle,
        native_handle,
    );
    const phys_device = try PhysicalDevice.init(
        alloc,
        instance.handle,
        surface.handle,
        drm_device,
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

    const command_pool = try CommandPool.init(dev, phys_device);

    const syncs = try Sync.init(dev);
    const render_finished = try Sync.initRenderFinished(alloc, dev, swapchain.images.len);

    return .{
        .gpa = alloc,
        .instance = instance,
        .surface = surface,
        .gpu = phys_device,
        .dev = dev,
        .sc = swapchain,
        .rp = render_pass,
        .fb = framebuffers,
        .cmd = command_pool,
        .syncs = syncs,
        .render_finished = render_finished,
    };
}

pub fn deinit(self: *Self) void {
    _ = vk.vkDeviceWaitIdle(self.dev.handle);
    Sync.deinitRenderFinished(self.gpa, self.dev, self.render_finished);
    Sync.deinit(self.syncs, self.dev);
    self.cmd.deinit(self.dev);
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
    self.clear_color = .{
        .float32 = .{
            @as(f32, @floatFromInt(color.rgba.r)) / 255.0,
            @as(f32, @floatFromInt(color.rgba.g)) / 255.0,
            @as(f32, @floatFromInt(color.rgba.b)) / 255.0,
            @as(f32, @floatFromInt(color.rgba.a)) / 255.0,
        },
    };
}

pub fn beginFrame(self: *Self) !void {
    _ = vk.vkWaitForFences(
        self.dev.handle,
        1,
        &self.syncs[self.current_frame].in_flight,
        vk.VK_TRUE,
        std.math.maxInt(u64),
    );

    const acq = vk.vkAcquireNextImageKHR(
        self.dev.handle,
        self.sc.handle,
        std.math.maxInt(u64),
        self.syncs[self.current_frame].image_available,
        null,
        &self.current_image,
    );
    if (acq == vk.VK_ERROR_OUT_OF_DATE_KHR) return error.SwapChainOutOfDate;

    if (vk.vkResetFences(self.dev.handle, 1, &self.syncs[self.current_frame].in_flight) != vk.VK_SUCCESS)
        log.err(.renderer, "failed to reset fences", .{});
    if (vk.vkResetCommandBuffer(self.cmd.buffers[self.current_frame], 0) != vk.VK_SUCCESS)
        log.err(.renderer, "failed to reset command buffer", .{});
    var begin_info: vk.VkCommandBufferBeginInfo = .{};
    begin_info.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    begin_info.flags = vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    if (vk.vkBeginCommandBuffer(self.cmd.buffers[self.current_frame], &begin_info) != vk.VK_SUCCESS)
        log.err(.renderer, "failed to begin command buffer", .{});

    var rp_info: vk.VkRenderPassBeginInfo = .{};
    rp_info.sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
    rp_info.renderPass = self.rp.handle;
    rp_info.framebuffer = self.fb[self.current_image];
    rp_info.renderArea = .{
        .offset = .{ .x = 0, .y = 0 },
        .extent = self.sc.extent,
    };
    rp_info.clearValueCount = 1;
    rp_info.pClearValues = &vk.VkClearValue{ .color = self.clear_color };
    vk.vkCmdBeginRenderPass(
        self.cmd.buffers[self.current_frame],
        &rp_info,
        vk.VK_SUBPASS_CONTENTS_INLINE,
    );
}
pub fn endFrame(self: *Self) !void {
    vk.vkCmdEndRenderPass(self.cmd.buffers[self.current_frame]);
    if (vk.vkEndCommandBuffer(self.cmd.buffers[self.current_frame]) != vk.VK_SUCCESS)
        log.err(.renderer, "failed to end command buffer", .{});

    var submit_info: vk.VkSubmitInfo = .{};
    submit_info.sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO;
    submit_info.waitSemaphoreCount = 1;
    submit_info.pWaitSemaphores = &self.syncs[self.current_frame].image_available;
    submit_info.pWaitDstStageMask = &@intCast(vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT);
    submit_info.commandBufferCount = 1;
    submit_info.pCommandBuffers = &self.cmd.buffers[self.current_frame];
    submit_info.signalSemaphoreCount = 1;
    submit_info.pSignalSemaphores = &self.render_finished[self.current_image];
    if (vk.vkQueueSubmit(
        self.dev.graphics_queue,
        1,
        &submit_info,
        self.syncs[self.current_frame].in_flight,
    ) != vk.VK_SUCCESS) return error.FailedToSubmit;

    var present_info: vk.VkPresentInfoKHR = .{};
    present_info.sType = vk.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
    present_info.waitSemaphoreCount = 1;
    present_info.pWaitSemaphores = &self.render_finished[self.current_image];
    present_info.swapchainCount = 1;
    present_info.pSwapchains = &self.sc.handle;
    present_info.pImageIndices = &self.current_image;
    const present_result = vk.vkQueuePresentKHR(self.dev.present_queue, &present_info);
    if (present_result != vk.VK_SUCCESS and present_result != vk.VK_SUBOPTIMAL_KHR)
        return error.FailedToPresent;

    self.current_frame = @mod((self.current_frame + 1), frames_in_flight);
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
