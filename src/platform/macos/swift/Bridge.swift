import AppKit
import Foundation

@MainActor
private var appDelegate: AppDelegate?
@MainActor
var activeWindows: [OpaquePointer: GameWindow] = [:]
@MainActor
private var globalEventHandler: EventHandler!

@MainActor
@_cdecl("init")
public func _init() {
  NSApplication.shared.setActivationPolicy(.regular)
  appDelegate = AppDelegate()
  NSApp.delegate = appDelegate
  globalEventHandler = EventHandler()
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
// TODO: This is not the right place to do this work?
@MainActor
@_cdecl("poll_events")
public func poll_events() {
  while let event = NSApp.nextEvent(
    matching: .any, until: nil, inMode: .default, dequeue: true
  ) {
    globalEventHandler.handleEvent(event)

    if event.type != .keyDown && event.type != .keyUp {
      NSApp.sendEvent(event)
    }
  }
}

@MainActor
@_cdecl("poll_mouse_event")
public func poll_mouse_event(
  x: UnsafeMutablePointer<Float>,
  y: UnsafeMutablePointer<Float>,
  scroll_x: UnsafeMutablePointer<Float>,
  scroll_y: UnsafeMutablePointer<Float>,
  button: UnsafeMutablePointer<UInt8>,
  isDown: UnsafeMutablePointer<UInt8>
) -> Bool {
  guard let event = globalEventHandler.pollNextMouse() else { return false }

  x.pointee = event.x
  y.pointee = event.y
  scroll_x.pointee = event.scroll_x
  scroll_y.pointee = event.scroll_y
  button.pointee = event.button
  isDown.pointee = event.isDown

  return true
}

@MainActor
@_cdecl("poll_key_event")
public func poll_key_event(
  keycode: UnsafeMutablePointer<UInt16>,
  isDown: UnsafeMutablePointer<UInt8>
) -> Bool {
  guard let event = globalEventHandler.pollNextKey() else { return false }

  keycode.pointee = event.keycode
  isDown.pointee = event.isDown

  return true
}
