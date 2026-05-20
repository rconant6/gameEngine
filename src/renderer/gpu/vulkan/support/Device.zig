const std = @import("std");
const Allocator = std.mem.Allocator;
const vk = @import("../c_bridge.zig").c;
const log = @import("debug").log;
const PhysicalDevice = @import("PhysicalDevice.zig");

const Self = @This();

handle: *vk.struct_VkDevice_T,
graphics_queue: *vk.struct_VkQueue_T,
present_queue: *vk.struct_VkQueue_T,

pub fn init(p_dev: *const PhysicalDevice) !Self {
    var dev: vk.VkDevice = null;
    var graphics_queue: vk.VkQueue = null;
    var present_queue: vk.VkQueue = null;

    const queue_priority: f32 = 1.0;
    if (p_dev.queue_families.graphics != p_dev.queue_families.present) {
        log.warn(
            .renderer,
            "Graphics and Preset queue families differ, G{d}  P{d}",
            .{
                p_dev.queue_families.graphics,
                p_dev.queue_families.present,
            },
        );
        return error.MultipleQueueFamilesNotImplmented;
    }

    var queue_create_info: vk.VkDeviceQueueCreateInfo = .{};
    queue_create_info.sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    queue_create_info.queueFamilyIndex = p_dev.queue_families.graphics;
    queue_create_info.queueCount = 1;
    queue_create_info.pQueuePriorities = &queue_priority;

    var dev_features: vk.VkPhysicalDeviceFeatures = .{};

    var dev_create_info: vk.VkDeviceCreateInfo = .{};
    dev_create_info.sType = vk.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    dev_create_info.pQueueCreateInfos = &queue_create_info;
    dev_create_info.queueCreateInfoCount = 1;
    dev_create_info.pEnabledFeatures = &dev_features;
    dev_create_info.enabledExtensionCount = 0;

    if (vk.vkCreateDevice(p_dev.handle, &dev_create_info, null, &dev) == vk.VK_SUCCESS) {
        vk.vkGetDeviceQueue(
            dev,
            p_dev.queue_families.graphics,
            0,
            &graphics_queue,
        );
        vk.vkGetDeviceQueue(
            dev,
            p_dev.queue_families.present,
            0,
            &present_queue,
        );

        return .{
            .handle = dev.?,
            .graphics_queue = graphics_queue.?,
            .present_queue = present_queue.?,
        };
    }

    return error.VkLogicalDeviceCreationFailure;
}

pub fn deinit(self: *Self) void {
    vk.vkDestroyDevice(self.handle);
}
