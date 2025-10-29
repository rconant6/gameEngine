import AppKit

class GameView: NSView {
  override func draw(_ dirtyRect: NSRect) {
    NSColor.darkGray.setFill()
    dirtyRect.fill()
  }

  override var acceptsFirstResponder: Bool {
    return true
  }
}
