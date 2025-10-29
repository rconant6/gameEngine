const std = @import("std");

const c = @cImport({
    @cInclude("macos_bridge.h");
});

const Window = struct {
    handle: c.WindowHandle,

    pub fn destroy(self: *Window) void {
        c.platform_destroy_window(self.handle);
    }

    pub fn shouldClose(self: *const Window) bool {
        return c.platform_window_should_close(self.handle);
    }

    pub fn swapBuffers(self: *Window) void {
        c.platform_swap_buffers(self.handle);
    }
};

pub fn init() !void {
    c.platform_init();
}

pub fn deinit() void {
    c.platform_deinit();
}

pub fn createWindow(options: struct {
    title: [:0]const u8,
    width: u32,
    height: u32,
}) !*Window {
    const handle = c.platform_create_window(
        @intCast(options.width),
        @intCast(options.height),
        options.title.ptr,
    );

    if (handle == null) {
        return error.WindowCreationFailed;
    }

    const window = try std.heap.c_allocator.create(Window);
    window.* = Window{ .handle = handle };
    return window;
}

pub fn pollEvents() void {
    c.platform_poll_events();
}

export fn engine_frame_callback(delta_time: f64) void {
    _ = delta_time;
}
