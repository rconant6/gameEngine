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
    drm_dev: u64,
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

    log.info(.renderer, "PhysicalDevice.init: drm_dev={d}", .{drm_dev});

    var best: ?Self = null;
    var best_score: u32 = std.math.maxInt(u32);

    for (devices) |*dev| {
        var props: vk.VkPhysicalDeviceProperties = undefined;
        vk.vkGetPhysicalDeviceProperties(dev.*, &props);
        log.info(.renderer, "GPU: {s}", .{&props.deviceName});

        if (try findQueueFamilies(gpa, dev.*, surface)) |families| {
            if (drm_dev != 0 and matchesDrmDevice(dev.*, drm_dev)) {
                log.info(.renderer, "DRM match: selected {s}", .{&props.deviceName});
                return .{ .handle = dev.*.?, .queue_families = families };
            }
            const score: u32 = switch (props.deviceType) {
                vk.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU => 0,
                vk.VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU => 1,
                vk.VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU => 2,
                else => 3,
            };
            if (score < best_score) {
                best_score = score;
                best = .{
                    .handle = dev.*.?,
                    .queue_families = families,
                };
            }
        }
    }

    if (best) |b| return b;

    log.err(.renderer, "No GPU found that supports Vulkan", .{});
    return error.NoSuitableDevice;
}

fn matchesDrmDevice(device: vk.VkPhysicalDevice, drm_dev: u64) bool {
    var drm_props = std.mem.zeroes(vk.VkPhysicalDeviceDrmPropertiesEXT);
    drm_props.sType = vk.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DRM_PROPERTIES_EXT;
    var props2 = std.mem.zeroes(vk.VkPhysicalDeviceProperties2);
    props2.sType = vk.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
    props2.pNext = &drm_props;
    vk.vkGetPhysicalDeviceProperties2(device, &props2);
    const major: i64 = @intCast(((drm_dev >> 8) & 0xfff) | (drm_dev >> 32));
    const minor: i64 = @intCast((drm_dev & 0xff) | (((drm_dev & 0xffffff00) >> 12) & ~@as(u64, 0xff)));
    log.info(.renderer, "  DRM props: hasRender={d} render={d}:{d} want={d}:{d}", .{
        drm_props.hasRender, drm_props.renderMajor, drm_props.renderMinor, major, minor,
    });
    if (drm_props.hasRender == vk.VK_FALSE) return false;
    return drm_props.renderMajor == major and drm_props.renderMinor == minor;
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
