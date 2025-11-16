import AppKit
import Foundation

@MainActor
private var appDelegate: AppDelegate?
@MainActor
private var activeWindows: [OpaquePointer: GameWindow] = [:]

@MainActor
@_cdecl("init")
public func _init() {
  NSApplication.shared.setActivationPolicy(.regular)
  appDelegate = AppDelegate()
  NSApp.delegate = appDelegate
}

@MainActor
@_cdecl("deinit")
public func _deinit() {
  activeWindows.removeAll()
  NSApp.terminate(nil)
}

@MainActor
@_cdecl("create_window")
public func create_window(
  width: Int32,
  height: Int32,
  title: UnsafePointer<CChar>?
) -> OpaquePointer? {
  let titleStr = String(cString: title!)
  let window = GameWindow(
    width: Int(width),
    height: Int(height),
    title: titleStr
  )

  let handle = OpaquePointer.init(Unmanaged.passUnretained(window).toOpaque())
  activeWindows[handle] = window

  window.makeKeyAndOrderFront(nil)
  NSApp.activate(ignoringOtherApps: true)

  return handle
}

@MainActor
@_cdecl("destroy_window")
public func destroy_window(window: OpaquePointer?) {
  guard let window = window else { return }
  activeWindows.removeValue(forKey: window)
}

@MainActor
@_cdecl("window_should_close")
public func window_should_close(window: OpaquePointer?) -> Bool {
  guard let window = window,
    let gameWindow = activeWindows[window]
  else { return true }
  return gameWindow.shouldClose
}

@MainActor
@_cdecl("get_window_scale_factor")
public func get_window_get_scale_factor(window: OpaquePointer?) -> Float {
  guard let window = window,
    let gameWindow = activeWindows[window]
  else { return 3.0 }

  return Float(gameWindow.backingScaleFactor)
}

@MainActor
@_cdecl("poll_events")
public func poll_events() {
  while let event = NSApp.nextEvent(
    matching: .any, until: nil, inMode: .default, dequeue: true
  ) {
    NSApp.sendEvent(event)
  }
}

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
