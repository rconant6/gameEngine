import AppKit

class GameWindow: NSWindow {
  var shouldClose = false
  private var gameView: GameView?
  private var pixelBuffer: UnsafePointer<UInt8>?
  private var pixelWidth: Int = 0
  private var pixelHeight: Int = 0

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

  func setPixelBuffer(pixels: UnsafePointer<UInt8>, width: Int, height: Int) {
    self.pixelBuffer = pixels
    self.pixelWidth = width
    self.pixelHeight = height
    gameView?.setPixelBuffer(pixels, width: width, height: height)
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
