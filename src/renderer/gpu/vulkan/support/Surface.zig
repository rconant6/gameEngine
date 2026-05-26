const vk = @import("../c_bridge.zig").c;
const log = @import("debug").log;

const Self = @This();

handle: *vk.struct_VkSurfaceKHR_T,

const WaylandHandles = struct {
    display: *anyopaque,
    surface: *anyopaque,
    drm_device: u64,
};

pub fn init(
    instance: *vk.struct_VkInstance_T,
    native_handle: *anyopaque,
) !Self {
    var surface: vk.VkSurfaceKHR = null;

    const handles: *WaylandHandles = @ptrCast(@alignCast(native_handle));
    const create_info: vk.VkWaylandSurfaceCreateInfoKHR = .{
        .sType = vk.VK_STRUCTURE_TYPE_WAYLAND_SURFACE_CREATE_INFO_KHR,
        .display = @ptrCast(handles.display),
        .surface = @ptrCast(handles.surface),
    };
    if (vk.vkCreateWaylandSurfaceKHR(instance, &create_info, null, &surface) != vk.VK_SUCCESS) {
        log.err(.renderer, "Failed to create Wayland surface", .{});
        return error.SurfaceCreationFailed_Wayland;
    }

    return .{ .handle = surface.? };
}

pub fn deinit(self: *Self, instance: *vk.struct_VkInstance_T) void {
    vk.vkDestroySurfaceKHR(instance, self.handle, null);
}
