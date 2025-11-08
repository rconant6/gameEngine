// import AppKit
// import MetalKit

// class MetalView: MTKView {
//   private var pixelBuffer: UnsafePointer<UInt8>?
//   private var pixelWidth: Int = 0
//   private var pixelHeight: Int = 0

//   func setPixelBuffer(_ buffer: UnsafePointer<UInt8>, width: Int, height: Int) {
//     self.pixelBuffer = buffer
//     self.pixelWidth = width
//     self.pixelHeight = height
//   }

//   override func draw(_ dirtyRect: NSRect) {
//     guard let pixelBuffer = pixelBuffer else {
//       NSColor.systemPink.setFill()
//       dirtyRect.fill()
//       return
//     }

//     let bytesPerPixel = 4
//     let bytesPerRow = pixelWidth * bytesPerPixel

//     var mutablePixels: UnsafeMutablePointer<UInt8>? = UnsafeMutablePointer(mutating: pixelBuffer)
//     guard
//       let imageRep = NSBitmapImageRep(
//         bitmapDataPlanes: &mutablePixels, pixelsWide: pixelWidth, pixelsHigh: pixelHeight,
//         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
//         colorSpaceName: .deviceRGB, bytesPerRow: bytesPerRow, bitsPerPixel: 32
//       )
//     else {
//       NSColor.systemRed.setFill()
//       dirtyRect.fill()
//       return
//     }

//     let image = NSImage(size: NSSize(width: pixelWidth, height: pixelHeight))
//     image.addRepresentation(imageRep)
//     image.draw(in: self.bounds)
//   }

//   override var acceptsFirstResponder: Bool {
//     return true
//   }
// }
