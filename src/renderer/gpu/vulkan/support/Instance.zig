const std = @import("std");
const vk = @import("../c_bridge.zig").c;

const Self = @This();

const validation_layer = "VK_LAYER_KHRONOS_validation";

handle: *vk.struct_VkInstance_T,
debug_messenger: vk.VkDebugUtilsMessengerEXT = null,

fn debugCallback(
    severity: vk.VkDebugUtilsMessageSeverityFlagBitsEXT,
    _: vk.VkDebugUtilsMessageTypeFlagsEXT,
    data: ?*const vk.VkDebugUtilsMessengerCallbackDataEXT,
    _: ?*anyopaque,
) callconv(.c) vk.VkBool32 {
    if (data) |d| {
        if (severity >= vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT) {
            std.debug.print("[VK] {s}\n", .{d.pMessage});
        }
    }
    return vk.VK_FALSE;
}

fn checkValidationLayerSupport() bool {
    var count: u32 = 0;
    _ = vk.vkEnumerateInstanceLayerProperties(&count, null);
    if (count == 0) return false;

    var layers: [64]vk.VkLayerProperties = undefined;
    var query_count: u32 = @min(count, 64);
    _ = vk.vkEnumerateInstanceLayerProperties(&query_count, &layers);

    for (layers[0..query_count]) |layer| {
        const name = std.mem.sliceTo(&layer.layerName, 0);
        if (std.mem.eql(u8, name, validation_layer)) return true;
    }
    return false;
}

pub fn init() !Self {
    var instance: vk.VkInstance = null;

    var app_info: vk.VkApplicationInfo = .{};
    app_info.sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO;
    app_info.apiVersion = vk.VK_API_VERSION_1_4;

    const has_validation = checkValidationLayerSupport();

    const base_extensions = [_][*c]const u8{
        "VK_KHR_surface",
        "VK_KHR_wayland_surface",
    };
    const debug_extensions = [_][*c]const u8{
        "VK_KHR_surface",
        "VK_KHR_wayland_surface",
        "VK_EXT_debug_utils",
    };

    const layers = [_][*c]const u8{validation_layer};

    var create_info: vk.VkInstanceCreateInfo = .{};
    create_info.sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    create_info.pApplicationInfo = &app_info;
    if (has_validation) {
        create_info.enabledExtensionCount = debug_extensions.len;
        create_info.ppEnabledExtensionNames = &debug_extensions;
        create_info.enabledLayerCount = layers.len;
        create_info.ppEnabledLayerNames = &layers;
    } else {
        create_info.enabledExtensionCount = base_extensions.len;
        create_info.ppEnabledExtensionNames = &base_extensions;
    }

    if (vk.vkCreateInstance(&create_info, null, &instance) != vk.VK_SUCCESS)
        return error.VkInstanceCreationFailure;

    const inst = instance.?;

    var debug_messenger: vk.VkDebugUtilsMessengerEXT = null;
    if (has_validation) {
        const create_fn: vk.PFN_vkCreateDebugUtilsMessengerEXT = @ptrCast(
            vk.vkGetInstanceProcAddr(inst, "vkCreateDebugUtilsMessengerEXT"),
        );
        if (create_fn) |f| {
            var msg_ci: vk.VkDebugUtilsMessengerCreateInfoEXT = .{};
            msg_ci.sType = vk.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
            msg_ci.messageSeverity =
                vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
                vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
            msg_ci.messageType =
                vk.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
                vk.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
                vk.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
            msg_ci.pfnUserCallback = debugCallback;
            _ = f(inst, &msg_ci, null, &debug_messenger);
        }
    }

    return .{
        .handle = inst,
        .debug_messenger = debug_messenger,
    };
}

pub fn deinit(self: *Self) void {
    if (self.debug_messenger) |messenger| {
        const destroy_fn: vk.PFN_vkDestroyDebugUtilsMessengerEXT = @ptrCast(
            vk.vkGetInstanceProcAddr(self.handle, "vkDestroyDebugUtilsMessengerEXT"),
        );
        if (destroy_fn) |f| f(self.handle, messenger, null);
    }
    vk.vkDestroyInstance(self.handle, null);
}
