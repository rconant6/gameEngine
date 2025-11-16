import AppKit
import MetalKit

class GameWindow: NSWindow {
  var shouldClose = false
  private var metalRenderer: MetalDisplayRenderer? = nil
  private var pixelBuffer: UnsafeMutablePointer<UInt8>? = nil
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

    let metalView = MTKView(frame: contentRect)
    metalView.layer?.contentsScale = 1.0
    metalView.isPaused = true
    metalView.enableSetNeedsDisplay = true
    self.contentView = metalView
  }

  func setPixelBuffer(buffer: UnsafeMutablePointer<UInt8>?, bufferLen: Int, width: Int, height: Int)
  {
    guard let metalView = self.contentView as? MTKView else { return }
    guard let pixels = buffer else { return }

    metalRenderer = MetalDisplayRenderer(
      view: metalView,
      pixelBufferPointer: pixels,
      pixelBufferLen: bufferLen,
      width: width,
      height: height,
    )

    metalView.delegate = metalRenderer
    metalView.device = metalRenderer?.device
  }

  func swapBuffers(toOffset offset: UInt32) {
    metalRenderer?.setOffset(offset)
    self.contentView?.needsDisplay = true
  }
}

extension GameWindow: NSWindowDelegate {
  func windowWillClose(_ notification: Notification) {
    shouldClose = true
  }
}
