import AppKit
import MetalKit

class GameMTKView: MTKView {
  override var acceptsFirstResponder: Bool { true }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    // Prevent macOS from swallowing Cmd+key combos.
    // Forward them as normal key events so our handler sees them.
    globalEventHandler.handleEvent(event)
    return true
  }
}

class GameWindow: NSWindow {
  var shouldClose = false

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

    guard let device = MTLCreateSystemDefaultDevice() else {
      fatalError("Metal is not supported on this device")
    }

    let metalView = GameMTKView(frame: contentRect, device: device)
    metalView.layer?.contentsScale = 1.0
    metalView.isPaused = true
    metalView.enableSetNeedsDisplay = true
    self.contentView = metalView
  }

  public func getMetalLayer() -> CAMetalLayer? {
    guard let metalView = self.contentView as? MTKView,
      let metalLayer = metalView.layer as? CAMetalLayer
    else { return nil }

    if metalLayer.device == nil {
      metalLayer.device = metalView.device
    }

    metalLayer.pixelFormat = .bgra8Unorm_srgb

    let scale = self.backingScaleFactor
    metalLayer.drawableSize = CGSize(
      width: self.frame.width * scale,
      height: self.frame.height * scale
    )
    return metalLayer
  }
}

extension GameWindow: NSWindowDelegate {
  func windowWillClose(_ notification: Notification) {
    shouldClose = true
  }
}
