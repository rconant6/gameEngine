#ifndef MACOS_BRIDGE_H
#define MACOS_BRIDGE_H

#include <stdint.h>
#include <stdbool.h>

typedef void* WindowHandle;

void init();
void deinit();
WindowHandle create_window(int32_t width, int32_t height, const char* title);
void destroy_window(WindowHandle window);
bool window_should_close(WindowHandle window);
void poll_events();
void swap_buffers(WindowHandle window);

#endif
