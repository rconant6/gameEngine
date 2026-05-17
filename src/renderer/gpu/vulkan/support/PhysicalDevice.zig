const std = @import("std");
const Allocator = std.mem.Allocator;
const vk = @import("../c_bridge.zig").c;
const log = @import("debug").log;

const Self = @This();

handle: *vk.struct_VkPhysicalDevice_T,

pub fn init(gpa: Allocator, instance: *vk.struct_VkInstance_T) !Self {
    var device_count: u32 = 0;
    _ = vk.vkEnumeratePhysicalDevices(instance, &device_count, null);
    if (device_count == 0) {
        log.err(.renderer, "No Vulkan-capable GPU found", .{});
        return error.NoVulkanSupportedDevices;
    }

    const devices = try gpa.alloc(vk.VkPhysicalDevice, device_count);
    defer gpa.free(devices);
    _ = vk.vkEnumeratePhysicalDevices(instance, &device_count, @ptrCast(devices.ptr));

    var best: vk.VkPhysicalDevice = null;
    for (devices) |dev| {
        var props: vk.VkPhysicalDeviceProperties = undefined;
        vk.vkGetPhysicalDeviceProperties(dev, &props);
        log.info(.renderer, "GPU: {s}", .{&props.deviceName});
        if (props.deviceType == vk.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU) {
            best = dev;
        }
        if (best == null) best = dev;
    }

    return .{ .handle = best.? };
}

pub fn deinit(_: *Self) void {}
