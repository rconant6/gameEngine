@MainActor
@_cdecl("set_pixel_buffer")
public func set_pixel_buffer(
  window: OpaquePointer?,
  pixels: UnsafeMutablePointer<UInt8>?,
  pixels_len: Int,
  width: Int32,
  height: Int32,
) {
  guard let window = window,
    let gameWindow = activeWindows[window],
    let pixels = pixels
  else { return }

  gameWindow.setPixelBuffer(
    buffer: pixels, bufferLen: pixels_len, width: Int(width), height: Int(height))
}

@MainActor
@_cdecl("swap_buffers")
public func swap_buffers(window: OpaquePointer?, offset: UInt32) {
  guard let window = window,
    let gameWindow = activeWindows[window]
  else { return }
  gameWindow.swapBuffers(toOffset: offset)
}
