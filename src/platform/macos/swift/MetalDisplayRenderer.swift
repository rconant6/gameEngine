import MetalKit

class MetalDisplayRenderer: NSObject, MTKViewDelegate {
  let device: MTLDevice
  private let commandQueue: MTLCommandQueue
  private let texture: MTLTexture
  private let wrappedBuffer: MTLBuffer

  public init?(
    view: MTKView,
    pixelBufferPointer: UnsafeMutableRawPointer,
    width: Int,
    height: Int,
  ) {
    guard let device = MTLCreateSystemDefaultDevice() else { return nil }
    self.device = device

    guard let queue = device.makeCommandQueue() else { return nil }
    self.commandQueue = queue

    let length = width * height * 4
    guard
      let buffer = device.makeBuffer(
        bytesNoCopy: pixelBufferPointer,
        length: length,
        options: .storageModeShared,
        deallocator: nil)
    else { return nil }
    self.wrappedBuffer = buffer

    let descriptor = MTLTextureDescriptor()
    descriptor.pixelFormat = .rgba8Unorm
    descriptor.width = width
    descriptor.height = height
    descriptor.usage = .shaderRead
    descriptor.storageMode = .shared

    guard
      let texture = buffer.makeTexture(
        descriptor: descriptor,
        offset: 0, bytesPerRow: width * 4
      )
    else { return nil }
    self.texture = texture

    super.init()

  }

  public func draw(in view: MTKView) {

    guard let drawable = view.currentDrawable,
      let commandBuffer = commandQueue.makeCommandBuffer(),
      let encoder = commandBuffer.makeBlitCommandEncoder()
    else { return }

    // TODO: need to get the right scale factor for the display back to the engine
    // print("Texture size: \(texture.width)×\(texture.height)")
    // print("Drawable size: \(drawable.texture.width)×\(drawable.texture.height)")
    // print("View size: \(view.bounds.size)")
    encoder.copy(
      from: self.texture,
      sourceSlice: 0,
      sourceLevel: 0,
      sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
      sourceSize: MTLSize(width: texture.width, height: texture.height, depth: 1),
      to: drawable.texture,
      destinationSlice: 0,
      destinationLevel: 0,
      destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
    )
    encoder.endEncoding()

    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {

  }
}
