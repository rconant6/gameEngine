const std = @import("std");
const Allocator = std.mem.Allocator;
const vk = @import("../c_bridge.zig").c;
const log = @import("debug").log;

const Self = @This();

handle: *vk.struct_VkPhysicalDevice_T,

pub fn init(gpa: Allocator, instance: *vk.struct_VkInstance_T) !Self {
    const device: vk.VkPhysicalDevice = null;

    var deviceCount: u32 = 0;
    _ = vk.vkEnumeratePhysicalDevices(instance, &deviceCount, null);
    log.info(.renderer, "Found: {d} devices", .{deviceCount});
    if (deviceCount == 0) {
        log.err(.renderer, "No gpu to support Vulkan", .{});
        return error.NoVulkanSupportedDevices;
    }

    // if (vk.vkCreateInstance(&createInfo, null, &instance) == vk.VK_SUCCESS) {
    //     return .{
    //         .handle = device.?,
    //     };
    // }

    return error.VkPhysicalDeviceFailure;
}
pub fn deinit(self: *Self) void {
    _ = self;
    //
}
