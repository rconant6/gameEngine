import AppKit

class GameWindow: NSWindow {
  var shouldClose = false
  private var gameView: GameView?

  init(width: Int, height: Int, title: String) {
    let contentRect = NSRect(
      x: 0, y: 0,
      width: CGFloat(width),
      height: CGFloat(height)
    )

    super.init(
      contentRect: contentRect,
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    self.title = title
    self.center()

    gameView = GameView(frame: contentRect)
    self.contentView = gameView

    self.delegate = self
  }

  func swapBuffers() {
    gameView?.needsDisplay = true
  }
}

extension GameWindow: NSWindowDelegate {
  func windowWillClose(_ notification: Notification) {
    shouldClose = true
  }
}
