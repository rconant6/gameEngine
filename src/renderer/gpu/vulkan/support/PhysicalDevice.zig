const std = @import("std");
const Allocator = std.mem.Allocator;
const vk = @import("../c_bridge.zig").c;
const log = @import("debug").log;

const Self = @This();

pub const QueueFamilies = struct {
    graphics: u32,
    present: u32,
};

handle: *vk.struct_VkPhysicalDevice_T,
queue_families: QueueFamilies,

pub fn init(
    gpa: Allocator,
    instance: *vk.struct_VkInstance_T,
    surface: *vk.struct_VkSurfaceKHR_T,
) !Self {
    var device_count: u32 = 0;
    _ = vk.vkEnumeratePhysicalDevices(instance, &device_count, null);
    if (device_count == 0) {
        log.err(.renderer, "No Vulkan-capable GPU found", .{});
        return error.NoVulkanSupportedDevices;
    }

    const devices = try gpa.alloc(vk.VkPhysicalDevice, device_count);
    defer gpa.free(devices);
    _ = vk.vkEnumeratePhysicalDevices(
        instance,
        &device_count,
        @ptrCast(devices.ptr),
    );

    for (devices) |*dev| {
        var props: vk.VkPhysicalDeviceProperties = undefined;
        vk.vkGetPhysicalDeviceProperties(dev.*, &props);
        log.info(.renderer, "GPU: {s}", .{&props.deviceName});

        if (try findQueueFamilies(gpa, dev.*, surface)) |families| {
            return .{
                .handle = dev.*.?,
                .queue_families = families,
            };
        }
    }

    log.err(.renderer, "No GPU found that supports Vulkan", .{});
    return error.NoSuitableDevice;
}

fn findQueueFamilies(
    gpa: Allocator,
    device: vk.VkPhysicalDevice,
    surface: *vk.struct_VkSurfaceKHR_T,
) !?QueueFamilies {
    var family_count: u32 = 0;
    vk.vkGetPhysicalDeviceQueueFamilyProperties(device, &family_count, null);

    const families = try gpa.alloc(vk.VkQueueFamilyProperties, family_count);
    defer gpa.free(families);
    vk.vkGetPhysicalDeviceQueueFamilyProperties(
        device,
        &family_count,
        families.ptr,
    );

    var graphics: ?u32 = null;
    var present: ?u32 = null;

    for (families, 0..) |family, i| {
        const idx: u32 = @intCast(i);

        if (family.queueFlags & vk.VK_QUEUE_GRAPHICS_BIT != 0) {
            graphics = idx;
        }

        var present_support: vk.VkBool32 = vk.VK_FALSE;
        _ = vk.vkGetPhysicalDeviceSurfaceSupportKHR(
            device,
            idx,
            surface,
            &present_support,
        );
        if (present_support == vk.VK_TRUE) {
            present = idx;
        }

        if (graphics != null and present != null) {
            return .{ .graphics = graphics.?, .present = present.? };
        }
    }

    return null;
}

pub fn deinit(_: *Self) void {}
