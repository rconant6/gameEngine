import AppKit
import Foundation
@MainActor
private var appDelegate: AppDelegate?
@MainActor
private var activeWindows: [OpaquePointer: GameWindow] = [:]

@MainActor
@_cdecl("platform_init")
public func platform_init() {
  NSApplication.shared.setActivationPolicy(.regular)
  appDelegate = AppDelegate()
  NSApp.delegate = appDelegate
}

@MainActor
@_cdecl("platform_deinit")
public func platform_deinit() {
  activeWindows.removeAll()
  NSApp.terminate(nil)
}

@MainActor
@_cdecl("platform_create_window")
public func platform_create_window(
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
@_cdecl("platform_destroy_window")
public func platform_destroy_window(window: OpaquePointer?) {
  guard let window = window else { return }
  activeWindows.removeValue(forKey: window)
}

@MainActor
@_cdecl("platform_window_should_close")
public func platform_window_should_close(window: OpaquePointer?) -> Bool {
  guard let window = window,
    let gameWindow = activeWindows[window]
  else { return true }
  return gameWindow.shouldClose
}

@MainActor
@_cdecl("platform_poll_events")
public func platform_poll_events() {
  while let event = NSApp.nextEvent(
    matching: .any, until: nil, inMode: .default, dequeue: true
  ) {
    NSApp.sendEvent(event)
  }
}

@MainActor
@_cdecl("platform_swap_buffers")
public func platform_swap_buffers(window: OpaquePointer?) {
  guard let window = window,
    let gameWindow = activeWindows[window]
  else { return }
  gameWindow.swapBuffers()
}
