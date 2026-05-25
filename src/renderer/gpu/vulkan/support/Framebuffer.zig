const std = @import("std");
const Allocator = std.mem.Allocator;
const vk = @import("../c_bridge.zig").c;
const Device = @import("Device.zig");
const Renderpass = @import("RenderPass.zig");

pub fn init(
    gpa: Allocator,
    dev: Device,
    render_pass: Renderpass,
    views: []vk.VkImageView,
    extent: vk.VkExtent2D,
) ![]vk.VkFramebuffer {
    const buffers = try gpa.alloc(vk.VkFramebuffer, views.len);

    for (views, 0..) |view, i| {
        var create_info: vk.VkFramebufferCreateInfo = .{};
        create_info.sType = vk.VK_STRUCTURE_TYPE_FRAMEBUFFER_ATTACHMENTS_CREATE_INFO;
        create_info.renderPass = render_pass.handle;
        create_info.attachmentCount = 1;
        create_info.pAttachments = &view;
        create_info.width = extent.width;
        create_info.height = extent.height;
        create_info.layers = 1;

        if (vk.vkCreateFramebuffer(dev.handle, &create_info, null, &buffers[i]) != vk.VK_SUCCESS)
            return error.UnableToCreateFrameBuffer;
    }

    return buffers;
}

pub fn deinit(gpa: Allocator, dev: Device, buffers: []vk.VkFramebuffer) void {
    for (buffers) |buf| {
        vk.vkDestroyFramebuffer(dev.handle, buf, null);
    }
    gpa.free(buffers);
}
