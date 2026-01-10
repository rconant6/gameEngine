#if USE_METAL
import MetalKit

class MetalDisplayRenderer: NSObject, MTKViewDelegate {
  let device: MTLDevice
  private let commandQueue: MTLCommandQueue
  private let texture: MTLTexture
  private let wrappedBuffer: MTLBuffer
  private var offset: UInt32 = 0

  public init?(
    view: MTKView,
    pixelBufferPointer: UnsafeMutableRawPointer,
    pixelBufferLen: Int,
    width: Int,
    height: Int,
  ) {
    guard let device = MTLCreateSystemDefaultDevice() else { return nil }
    self.device = device

    guard let queue = device.makeCommandQueue() else { return nil }
    self.commandQueue = queue

    guard
      let buffer = device.makeBuffer(
        bytesNoCopy: pixelBufferPointer,
        length: pixelBufferLen,
        options: .storageModeShared,
        deallocator: nil)
    else { return nil }
    self.wrappedBuffer = buffer

    let descriptor = MTLTextureDescriptor()
    descriptor.pixelFormat = .bgra8Unorm
    descriptor.width = width
    descriptor.height = height * 3
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

    print("Buffer size: \(pixelBufferLen) bytes")
    print("Texture dimensions: \(descriptor.width)×\(descriptor.height)")
    print("Expected to see: \(pixelBufferLen / 4) pixels")
    print("Texture sees: \(descriptor.width * descriptor.height) pixels")
  }

  public func setOffset(_ offset: UInt32) {
    self.offset = offset
  }

  public func draw(in view: MTKView) {
    guard let drawable = view.currentDrawable,
      let commandBuffer = commandQueue.makeCommandBuffer(),
      let encoder = commandBuffer.makeBlitCommandEncoder()
    else { return }

    let sourceY = (Int(offset) / 4) / self.texture.width

    encoder.copy(
      from: self.texture,
      sourceSlice: 0,
      sourceLevel: 0,
      sourceOrigin: MTLOrigin(x: 0, y: sourceY, z: 0),
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
#endif
