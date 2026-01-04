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
    self.isDown = isDown ? 0 : 1
  }
}
@frozen
public struct RawMouseEvent {
  var x: Float
  var y: Float
  var button: UInt8
  var isDown: UInt8
  var _padding: UInt16 = 0

  public init(
    x: Float,
    y: Float,
    button: UInt8,
    isDown: UInt8,
    _padding: UInt16 = 0,
  ) {
    self.x = x
    self.y = y
    self.button = button
    self.isDown = isDown
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
      .otherMouseDown, .otherMouseUp:
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
    let x = loc.x
    let y = loc.y
    let rawEvent = RawMouseEvent(
      x: Float(x), y: Float(y), button: UInt8(mouseButton), isDown: isDown, _padding: 0)

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
