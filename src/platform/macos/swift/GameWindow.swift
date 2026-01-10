import AppKit

#if USE_METAL
import MetalKit
#endif

class GameWindow: NSWindow {
  var shouldClose = false
  #if USE_METAL
  private var metalRenderer: MetalDisplayRenderer? = nil
  #endif
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

    #if USE_METAL
    guard let device = MTLCreateSystemDefaultDevice() else {
      fatalError("Metal is not supported on this device")
    }

    let metalView = MTKView(frame: contentRect, device: device)
    metalView.layer?.contentsScale = 1.0
    metalView.isPaused = true
    metalView.enableSetNeedsDisplay = true
    self.contentView = metalView
    #else
    // CPU renderer: use a simple NSView
    let simpleView = NSView(frame: contentRect)
    self.contentView = simpleView
    #endif
  }

  func setPixelBuffer(buffer: UnsafeMutablePointer<UInt8>?, bufferLen: Int, width: Int, height: Int)
  {
    #if USE_METAL
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
    #else
    // CPU renderer doesn't use this
    _ = buffer
    _ = bufferLen
    _ = width
    _ = height
    #endif
  }

  func swapBuffers(toOffset offset: UInt32) {
    #if USE_METAL
    metalRenderer?.setOffset(offset)
    self.contentView?.needsDisplay = true
    #else
    // CPU renderer doesn't use this
    _ = offset
    #endif
  }

  public func getMetalLayer() -> CAMetalLayer? {
    #if USE_METAL
    guard let metalView = self.contentView as? MTKView,
      let metalLayer = metalView.layer as? CAMetalLayer
    else { return nil }

    if metalLayer.device == nil {
      metalLayer.device = metalView.device
    }

    metalLayer.pixelFormat = .bgra8Unorm

    let scale = self.backingScaleFactor
    metalLayer.drawableSize = CGSize(
      width: self.frame.width * scale,
      height: self.frame.height * scale
    )
    return metalLayer
    #else
    return nil
    #endif
  }
}

extension GameWindow: NSWindowDelegate {
  func windowWillClose(_ notification: Notification) {
    shouldClose = true
  }
}
