const vk = @import("../c_bridge.zig").c;

const Self = @This();

handle: *vk.struct_VkInstance_T,

pub fn init() !Self {
    var instance: vk.VkInstance = null;

    var appInfo: vk.VkApplicationInfo = .{};
    appInfo.sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    appInfo.apiVersion = vk.VK_API_VERSION_1_4;

    const extenstions = [_][*c]const u8{
        "VK_KHR_surface",
    };

    var createInfo: vk.VkInstanceCreateInfo = .{};
    createInfo.sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    createInfo.pApplicationInfo = &appInfo;
    createInfo.enabledExtensionCount = extenstions.len;
    createInfo.ppEnabledExtensionNames = &extenstions;

    if (vk.vkCreateInstance(&createInfo, null, &instance) == vk.VK_SUCCESS) {
        return .{
            .handle = instance.?,
        };
    }

    return error.VkInstanceCreationFailure;
}

pub fn deinit(self: *Self) void {
    vk.vkDestroyInstance(self.handle, null);
}
