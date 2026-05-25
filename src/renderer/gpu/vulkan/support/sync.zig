const vk = @import("../c_bridge.zig").c;
const consts = @import("constants.zig");
const Device = @import("Device.zig");

const frames_in_flight = consts.frames_in_flight;

pub const FrameSync = struct {
    image_available: *vk.struct_VkSemaphore_T,
    render_finished: *vk.struct_VkSemaphore_T,
    in_flight: *vk.struct_VkFence_T,
};

pub fn init(dev: Device) ![frames_in_flight]FrameSync {
    var img_sem: vk.VkSemaphore = null;
    var rend_sem: vk.VkSemaphore = null;
    var fence: vk.VkFence = null;

    var syncs: [frames_in_flight]FrameSync = undefined;
    for (&syncs) |*sync| {
        var sci: vk.VkSemaphoreCreateInfo = .{};
        sci.sType = vk.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;
        if (vk.vkCreateSemaphore(dev.handle, &sci, null, &img_sem) != vk.VK_SUCCESS)
            return error.SemaphoreCreationFailed1;
        if (vk.vkCreateSemaphore(dev.handle, &sci, null, &rend_sem) != vk.VK_SUCCESS)
            return error.SemaphoreCreationFailed2;

        var fci: vk.VkFenceCreateInfo = .{};
        fci.sType = vk.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
        fci.flags = vk.VK_FENCE_CREATE_SIGNALED_BIT;
        if (vk.vkCreateFence(dev.handle, &fci, null, &fence) != vk.VK_SUCCESS)
            return error.FenceCreationFailed;

        sync.* = .{
            .image_available = img_sem.?,
            .render_finished = rend_sem.?,
            .in_flight = fence.?,
        };
    }

    return syncs;
}

pub fn deinit(syncs: [frames_in_flight]FrameSync, dev: Device) void {
    for (syncs) |sync| {
        vk.vkDestroySemaphore(dev.handle, sync.image_available, null);
        vk.vkDestroySemaphore(dev.handle, sync.render_finished, null);
        vk.vkDestroyFence(dev.handle, sync.in_flight, null);
    }
}
