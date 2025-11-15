#ifndef MACOS_BRIDGE_H
#define MACOS_BRIDGE_H

#include <stdbool.h>
#include <stdint.h>

typedef void *WindowHandle;

void init();
void deinit();

WindowHandle create_window(int32_t width, int32_t height, const char *title);
void destroy_window(WindowHandle window);
float get_window_scale_factor(WindowHandle window);
bool window_should_close(WindowHandle window);
void poll_events();
void swap_buffers(WindowHandle window);
void set_pixel_buffer(WindowHandle window, void *pixels, uint32_t width,
                      uint32_t height);

#endif
