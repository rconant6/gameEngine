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

class EventHandler {
  private var eventQueue: [RawKeyEvent] = []

  func handleKeyEvent(_ event: NSEvent) {
    let keyCode = event.keyCode
    let isDown = event.type == .keyDown
    let rawEvent = RawKeyEvent(keycode: keyCode, isDown: isDown)

    self.eventQueue.append(rawEvent)
  }
  func pollNext() -> RawKeyEvent? {
    if self.eventQueue.isEmpty { return nil }
    let first = self.eventQueue.first
    self.eventQueue.remove(at: 0)
    return first
  }
}
