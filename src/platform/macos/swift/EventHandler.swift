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
      .scrollWheel:
      handleMouseEvent(event)
    default: break  // stuff not needed/supported (yet)
    }
  }

  private func handleKeyEvent(_ event: NSEvent) {
    let keyCode = event.keyCode
    let isDown = event.type == .keyDown
    let rawEvent = RawKeyEvent(keycode: keyCode, isDown: isDown)

    self.keyEventQueue.append(rawEvent)
  }
  func handleMouseEvent(_ event: NSEvent) {
    let mouseButton = event.buttonNumber
    let isDown: UInt8 =
      (event.type == .leftMouseDown || event.type == .rightMouseDown
        || event.type == .otherMouseDown) ? 1 : 0
    let loc = event.locationInWindow
    let (scroll_x, scroll_y) =
      (event.type == .scrollWheel) ? (event.scrollingDeltaX, event.scrollingDeltaY) : (0, 0)
    let rawEvent = RawMouseEvent(
      x: Float(loc.x), y: Float(loc.y),
      scroll_x: Float(scroll_x),
      scroll_y: Float(scroll_y),
      button: UInt8(mouseButton), isDown: isDown, padding: 0)

    self.mouseEventQueue.append(rawEvent)
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
