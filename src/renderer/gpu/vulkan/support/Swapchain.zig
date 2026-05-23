const std = @import("std");
const Allocator = std.mem.Allocator;
const vk = @import("../c_bridge.zig").c;
const Surface = @import("Surface.zig");
const PhysicalDevice = @import("PhysicalDevice.zig");
const Device = @import("Device.zig");

const Self = @This();

gpa: Allocator,
handle: *vk.struct_VkSwapchainKHR_T,
images: []vk.VkImage,
views: []vk.VkImageView,
format: vk.VkFormat = 0,
extent: vk.VkExtent2D,

pub fn init(alloc: Allocator, dev: Device, gpu: PhysicalDevice, surface: Surface, width: u32, height: u32) !Self {
    const capes = try queryCaps(gpu, surface);

    const extent = chooseExtent(&capes, width, height);
    const fmt = try chooseFormat(alloc, gpu, surface);
    const mode = try choosePresentMode(alloc, gpu, surface);

    var handle: vk.VkSwapchainKHR = null;
    var create_info: vk.VkSwapchainCreateInfoKHR = .{};
    create_info.sType = vk.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
    create_info.surface = surface.handle;
    const max_count = if (capes.maxImageCount == 0) capes.minImageCount + 1 else capes.maxImageCount;
    create_info.minImageCount = std.math.clamp(capes.minImageCount + 1, capes.minImageCount, max_count);
    create_info.imageFormat = fmt.format;
    create_info.imageColorSpace = fmt.colorSpace;
    create_info.imageExtent = extent;
    create_info.imageArrayLayers = 1;
    create_info.imageUsage = vk.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
    create_info.imageSharingMode = vk.VK_SHARING_MODE_EXCLUSIVE;
    create_info.preTransform = capes.currentTransform;
    create_info.compositeAlpha = vk.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
    create_info.presentMode = mode;
    create_info.clipped = vk.VK_TRUE;
    create_info.oldSwapchain = null;

    if (vk.vkCreateSwapchainKHR(dev.handle, &create_info, null, &handle) != vk.VK_SUCCESS)
        return error.SwapchainCreateFailed;

    const images = try createImages(alloc, dev, handle.?);
    const views = try createImageViews(alloc, dev, images, fmt.format);

    return .{
        .gpa = alloc,
        .extent = extent,
        .handle = handle.?,
        .images = images,
        .views = views,
        .format = fmt.format,
    };
}

pub fn deinit(self: *Self, dev: *const Device) void {
    for (self.views) |view| {
        vk.vkDestroyImageView(dev.handle, view, null);
    }
    self.gpa.free(self.views);
    self.gpa.free(self.images);

    vk.vkDestroySwapchainKHR(dev.handle, self.handle, null);
}

fn createImages(
    gpa: Allocator,
    dev: Device,
    handle: *vk.struct_VkSwapchainKHR_T,
) ![]vk.VkImage {
    var image_count: u32 = 0;
    if (vk.vkGetSwapchainImagesKHR(
        dev.handle,
        handle,
        &image_count,
        null,
    ) != vk.VK_SUCCESS)
        return error.VkImageCreationFailure;

    const images = try gpa.alloc(vk.VkImage, image_count);
    if (vk.vkGetSwapchainImagesKHR(
        dev.handle,
        handle,
        &image_count,
        images.ptr,
    ) != vk.VK_SUCCESS)
        return error.VkImageCreationFailure;

    return images;
}

fn createImageViews(
    gpa: Allocator,
    dev: Device,
    images: []vk.VkImage,
    format: vk.VkFormat,
) ![]vk.VkImageView {
    const views = try gpa.alloc(vk.VkImageView, images.len);

    for (images, 0..) |image, i| {
        var create_info: vk.VkImageViewCreateInfo = .{};
        create_info.sType = vk.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
        create_info.image = image;
        create_info.format = format;
        create_info.viewType = vk.VK_IMAGE_VIEW_TYPE_2D;
        create_info.components = .{
            .r = vk.VK_COMPONENT_SWIZZLE_IDENTITY,
            .g = vk.VK_COMPONENT_SWIZZLE_IDENTITY,
            .b = vk.VK_COMPONENT_SWIZZLE_IDENTITY,
            .a = vk.VK_COMPONENT_SWIZZLE_IDENTITY,
        };
        create_info.subresourceRange = .{
            .aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT,
            .baseMipLevel = 0,
            .levelCount = 1,
            .baseArrayLayer = 0,
            .layerCount = 1,
        };

        if (vk.vkCreateImageView(
            dev.handle,
            &create_info,
            null,
            &views[i],
        ) != vk.VK_SUCCESS)
            return error.UnableToCreateImageViews;
    }

    return views;
}

fn queryCaps(
    gpu: PhysicalDevice,
    surface: Surface,
) !vk.VkSurfaceCapabilitiesKHR {
    var capes: vk.VkSurfaceCapabilitiesKHR = undefined;
    if (vk.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(
        gpu.handle,
        surface.handle,
        &capes,
    ) != 0)
        return error.GPUDoesNotSupportKHR;
    return capes;
}

fn chooseExtent(
    capes: *const vk.VkSurfaceCapabilitiesKHR,
    width: u32,
    height: u32,
) vk.VkExtent2D {
    // TODO: we know we're on wayland, its always going to be 0xFFFFFFFF so we have to tell the width/height
    return .{
        .width = std.math.clamp(
            width,
            capes.minImageExtent.width,
            capes.maxImageExtent.width,
        ),
        .height = std.math.clamp(
            height,
            capes.minImageExtent.height,
            capes.maxImageExtent.height,
        ),
    };
}

fn chooseFormat(
    gpa: Allocator,
    gpu: PhysicalDevice,
    surface: Surface,
) !vk.VkSurfaceFormatKHR {
    var count: u32 = 0;
    if (vk.vkGetPhysicalDeviceSurfaceFormatsKHR(
        gpu.handle,
        surface.handle,
        &count,
        null,
    ) != vk.VK_SUCCESS)
        return error.SurfaceFormatsQueryFailed;

    const formats = try gpa.alloc(vk.VkSurfaceFormatKHR, count);
    defer gpa.free(formats);
    if (vk.vkGetPhysicalDeviceSurfaceFormatsKHR(
        gpu.handle,
        surface.handle,
        &count,
        formats.ptr,
    ) != vk.VK_SUCCESS)
        return error.SurfaceFormatsQueryFailed;

    for (formats) |fmt| {
        if (fmt.format == vk.VK_FORMAT_B8G8R8A8_SRGB and
            fmt.colorSpace == vk.VK_COLORSPACE_SRGB_NONLINEAR_KHR)
            return fmt;
    }

    return formats[0];
}

fn choosePresentMode(
    gpa: Allocator,
    gpu: PhysicalDevice,
    surface: Surface,
) !vk.VkPresentModeKHR {
    var count: u32 = 0;
    if (vk.vkGetPhysicalDeviceSurfacePresentModesKHR(
        gpu.handle,
        surface.handle,
        &count,
        null,
    ) != vk.VK_SUCCESS)
        return error.PresentModesQueryFailed;

    const modes = try gpa.alloc(vk.VkPresentModeKHR, count);
    defer gpa.free(modes);
    if (vk.vkGetPhysicalDeviceSurfacePresentModesKHR(
        gpu.handle,
        surface.handle,
        &count,
        modes.ptr,
    ) != vk.VK_SUCCESS)
        return error.PresentModesQueryFailed;

    for (modes) |m| {
        if (m == vk.VK_PRESENT_MODE_MAILBOX_KHR) return m;
    }

    return vk.VK_PRESENT_MODE_FIFO_KHR;
}
