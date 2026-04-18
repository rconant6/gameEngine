import Cocoa

@frozen
public struct RawKeyEvent {
  var keycode: UInt16
  var isDown: UInt8
  var _padding: UInt8 = 0

  public init(
    keycode: UInt16,
    isDown: Bool,
  ) {
    self.keycode = keycode
    self.isDown = isDown ? 1 : 0
  }
}
@frozen
public struct RawMouseEvent {
  var x: Float
  var y: Float
  var scroll_x: Float
  var scroll_y: Float
  var button: UInt8
  var isDown: UInt8
  var _padding: UInt16 = 0

  public init(
    x: Float,
    y: Float,
    scroll_x: Float,
    scroll_y: Float,
    button: UInt8,
    isDown: UInt8,
    padding: UInt16,
  ) {
    self.x = x
    self.y = y
    self.scroll_x = scroll_x
    self.scroll_y = scroll_y
    self.button = button
    self.isDown = isDown
    self._padding = 0
  }
}

class EventHandler {
  private var keyEventQueue: [RawKeyEvent] = []
  private var mouseEventQueue: [RawMouseEvent] = []

  func handleEvent(_ event: NSEvent) {
    switch event.type {
    case .keyDown, .keyUp:
      handleKeyEvent(event)
    case .leftMouseDown, .leftMouseUp,
      .rightMouseDown, .rightMouseUp,
      .otherMouseDown, .otherMouseUp,
      .scrollWheel,
      .mouseMoved, .leftMouseDragged, .rightMouseDragged:
      handleMouseEvent(event)
    case .flagsChanged:
      handleFlagsChanged(event)
    default: break  // stuff not needed/supported (yet)
    }
  }

  private func handleFlagsChanged(_ event: NSEvent) {
    let flags = event.modifierFlags
    let keyCode = event.keyCode

    // macOS fires flagsChanged once per modifier state change.
    // Determine if this specific key is now down based on its flag.
    let isDown: Bool
    switch keyCode {
    case 0x37: // Left Cmd
      isDown = flags.contains(.command)
    case 0x36: // Right Cmd
      isDown = flags.contains(.command)
    case 0x38: // Left Shift
      isDown = flags.contains(.shift)
    case 0x3C: // Right Shift
      isDown = flags.contains(.shift)
    case 0x3B: // Left Control
      isDown = flags.contains(.control)
    case 0x3E: // Right Control
      isDown = flags.contains(.control)
    case 0x3A: // Left Option
      isDown = flags.contains(.option)
    case 0x3D: // Right Option
      isDown = flags.contains(.option)
    default:
      return
    }

    self.keyEventQueue.append(RawKeyEvent(keycode: keyCode, isDown: isDown))
  }

  private func handleKeyEvent(_ event: NSEvent) {
    let keyCode = event.keyCode
    let isDown = event.type == .keyDown
    let rawEvent = RawKeyEvent(keycode: keyCode, isDown: isDown)

    self.keyEventQueue.append(rawEvent)
  }
  func handleMouseEvent(_ event: NSEvent) {
    let loc = event.locationInWindow

    switch event.type {
    case .leftMouseDown, .rightMouseDown, .otherMouseDown:
      self.mouseEventQueue.append(RawMouseEvent(
        x: Float(loc.x), y: Float(loc.y),
        scroll_x: 0, scroll_y: 0,
        button: UInt8(event.buttonNumber), isDown: 1, padding: 0))
    case .leftMouseUp, .rightMouseUp, .otherMouseUp:
      self.mouseEventQueue.append(RawMouseEvent(
        x: Float(loc.x), y: Float(loc.y),
        scroll_x: 0, scroll_y: 0,
        button: UInt8(event.buttonNumber), isDown: 0, padding: 0))
    case .scrollWheel:
      self.mouseEventQueue.append(RawMouseEvent(
        x: Float(loc.x), y: Float(loc.y),
        scroll_x: Float(event.scrollingDeltaX), scroll_y: Float(event.scrollingDeltaY),
        button: 0xFF, isDown: 0, padding: 0))
    case .mouseMoved, .leftMouseDragged, .rightMouseDragged:
      self.mouseEventQueue.append(RawMouseEvent(
        x: Float(loc.x), y: Float(loc.y),
        scroll_x: 0, scroll_y: 0,
        button: 0xFF, isDown: 0, padding: 0))
    default: break
    }
  }

  func pollNextMouse() -> RawMouseEvent? {
    if self.mouseEventQueue.isEmpty { return nil }

    let first = self.mouseEventQueue.first
    self.mouseEventQueue.remove(at: 0)

    return first
  }

  func pollNextKey() -> RawKeyEvent? {
    if self.keyEventQueue.isEmpty { return nil }

    let first = self.keyEventQueue.first
    self.keyEventQueue.remove(at: 0)

    return first
  }
}
