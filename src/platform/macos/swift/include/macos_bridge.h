#ifndef MACOS_BRIDGE_H
#define MACOS_BRIDGE_H

#include <stdbool.h>
#include <stdint.h>

typedef void *WindowHandle;
struct RawKeyEvent {
  uint16_t code;
  uint8_t isDown;
  uint8_t _padding;
};
struct RawMouseEvent {
  float x;
  float y;
  float scroll_x;
  float scroll_y;
  uint8_t button;
  uint8_t isDown;
  uint16_t _padding;
};

void init();
void deinit();

WindowHandle create_window(int32_t width, int32_t height, const char *title);
void destroy_window(WindowHandle window);
float get_window_scale_factor(WindowHandle window);
bool window_should_close(WindowHandle window);
void swap_buffers(WindowHandle window, uint32_t offest);
void set_pixel_buffer(WindowHandle window, void *pixels, uint32_t width,
                      uint32_t height);

void poll_events();
bool poll_key_event(uint16_t *keycode, uint8_t *isDown);
bool poll_mouse_event(float *x, float *y, uint8_t *button, uint8_t *isDown,
                      float *scroll_x, float *scroll_y);

#endif
