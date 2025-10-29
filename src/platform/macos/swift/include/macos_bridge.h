#ifndef MACOS_BRIDGE_H
#define MACOS_BRIDGE_H

#include <stdint.h>
#include <stdbool.h>

typedef void* WindowHandle;

void platform_init();
void platform_deinit();
WindowHandle platform_create_window(int32_t width, int32_t height, const char* title);
void platform_destroy_window(WindowHandle window);
bool platform_window_should_close(WindowHandle window);
void platform_poll_events();
void platform_swap_buffers(WindowHandle window);

extern void engine_frame_callback(double dt);

#endif
