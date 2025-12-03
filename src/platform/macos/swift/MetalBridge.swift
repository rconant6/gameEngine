import Metal
import MetalKit
import QuartzCore

// MARK: Device and queue creation
@_cdecl("metal_create_device")
public func metal_create_device() -> OpaquePointer? {
  guard let device = MTLCreateSystemDefaultDevice() else {
    return nil
  }
  return OpaquePointer(Unmanaged.passRetained(device).toOpaque())
}
@_cdecl("metal_create_command_queue")
public func metal_create_command_queue(device: OpaquePointer) -> OpaquePointer? {
  let dev = Unmanaged<MTLDevice>.fromOpaque(UnsafeRawPointer(device)).takeUnretainedValue()
  guard let cmdQueue = dev.makeCommandQueue() else {
    return nil
  }
  return OpaquePointer(Unmanaged.passRetained(cmdQueue).toOpaque())
}

// MARK: Buffer management
@_cdecl("metal_create_command_buffer")
public func metal_create_command_buffer(queue: OpaquePointer) -> OpaquePointer? {
  let q = Unmanaged<MTLCommandQueue>.fromOpaque(UnsafeRawPointer(queue)).takeUnretainedValue()
  guard let cmdBuf = q.makeCommandBuffer() else {
    return nil
  }
  return OpaquePointer(Unmanaged.passRetained(cmdBuf).toOpaque())
}
@_cdecl("metal_command_buffer_commit")
public func metal_command_buffer_commit(buffer: OpaquePointer) {
  let buf = Unmanaged<MTLCommandBuffer>.fromOpaque(UnsafeRawPointer(buffer)).takeUnretainedValue()
  buf.commit()
}
@_cdecl("metal_command_buffer_present_drawable")
public func metal_command_buffer_present_drawable(buffer: OpaquePointer, drawable: OpaquePointer) {
  let buf = Unmanaged<MTLCommandBuffer>.fromOpaque(UnsafeRawPointer(buffer)).takeUnretainedValue()
  let draw = Unmanaged<CAMetalDrawable>.fromOpaque(UnsafeRawPointer(drawable)).takeUnretainedValue()
  buf.present(draw)
}

// MARK: Layer and Drawable access
@MainActor
@_cdecl("metal_get_layer_from_view")
public func metal_get_layer_from_view(window: OpaquePointer?) -> UnsafeMutableRawPointer? {
  guard let window = window,
    let gameWindow = activeWindows[window],
    let layer = gameWindow.getMetalLayer()
  else { return nil }

  return Unmanaged.passUnretained(layer).toOpaque()
}
@_cdecl("metal_layer_next_drawable")
public func metal_layer_next_drawable(layer: OpaquePointer) -> OpaquePointer? {
  let l = Unmanaged<CAMetalLayer>.fromOpaque(UnsafeRawPointer(layer)).takeUnretainedValue()
  guard let nextLayer = l.nextDrawable() else { return nil }
  return OpaquePointer(Unmanaged.passRetained(nextLayer).toOpaque())
}
@_cdecl("metal_drawable_get_texture")
public func metal_drawable_get_texture(drawable: OpaquePointer) -> OpaquePointer? {
  let d = Unmanaged<CAMetalDrawable>.fromOpaque(UnsafeRawPointer(drawable)).takeUnretainedValue()
  return OpaquePointer(Unmanaged.passRetained(d.texture).toOpaque())
}

// MARK: Buffer management
@_cdecl("metal_device_create_buffer")
public func metal_device_create_buffer(device: OpaquePointer, length: UInt64, options: UInt64)
  -> OpaquePointer?
{
  let dev = Unmanaged<MTLDevice>.fromOpaque(UnsafeRawPointer(device)).takeUnretainedValue()
  let resourceOptions = MTLResourceOptions.init(rawValue: UInt(options))
  guard let buffer = dev.makeBuffer(length: Int(length), options: resourceOptions) else {
    return nil
  }
  return OpaquePointer(Unmanaged.passRetained(buffer).toOpaque())
}
@_cdecl("metal_buffer_contents")
public func metal_buffer_contents(buffer: OpaquePointer) -> UnsafeMutableRawPointer? {
  let buf = Unmanaged<MTLBuffer>.fromOpaque(UnsafeRawPointer(buffer)).takeUnretainedValue()
  return buf.contents()
}

// MARK: Shader management
@_cdecl("metal_device_create_default_library")
public func metal_device_create_default_library(device: OpaquePointer) -> OpaquePointer? {
  let dev = Unmanaged<MTLDevice>.fromOpaque(UnsafeRawPointer(device)).takeUnretainedValue()
  guard let lib = dev.makeDefaultLibrary() else { return nil }
  return OpaquePointer(Unmanaged.passRetained(lib).toOpaque())
}
@_cdecl("metal_library_create_function")
public func metal_library_create_function(library: OpaquePointer, name: UnsafePointer<CChar>, )
  -> OpaquePointer?
{
  let lib = Unmanaged<MTLLibrary>.fromOpaque(UnsafeRawPointer(library)).takeUnretainedValue()
  let funcName = String(cString: name)
  guard let function = lib.makeFunction(name: funcName) else { return nil }
  return OpaquePointer(Unmanaged.passRetained(function).toOpaque())
}
@_cdecl("metal_device_create_library_from_file")
public func metal_device_create_library_from_file(
  device: OpaquePointer,
  path: UnsafePointer<CChar>
) -> OpaquePointer? {
  let dev = Unmanaged<MTLDevice>.fromOpaque(UnsafeRawPointer(device)).takeUnretainedValue()
  let pathString = String(cString: path)
  let url = URL(fileURLWithPath: pathString)

  guard let library = try? dev.makeLibrary(URL: url) else {
    return nil
  }

  return OpaquePointer(Unmanaged.passRetained(library).toOpaque())
}

// MARK: Pipeline State Creation
@_cdecl("metal_create_render_pipeline_state")
public func metal_create_render_pipeline_state(
  device: OpaquePointer, vertexFn: OpaquePointer, fragmentFn: OpaquePointer,
  pixelFormat: UInt64
) -> OpaquePointer? {
  let dev = Unmanaged<MTLDevice>.fromOpaque(UnsafeRawPointer(device)).takeUnretainedValue()
  let vf = Unmanaged<MTLFunction>.fromOpaque(UnsafeRawPointer(vertexFn)).takeUnretainedValue()
  let ff = Unmanaged<MTLFunction>.fromOpaque(UnsafeRawPointer(fragmentFn)).takeUnretainedValue()

  let vertexDesc = MTLVertexDescriptor()

  vertexDesc.attributes[0].format = .float2
  vertexDesc.attributes[0].offset = 0
  vertexDesc.attributes[0].bufferIndex = 0

  vertexDesc.attributes[1].format = .float4
  vertexDesc.attributes[1].offset = 8
  vertexDesc.attributes[1].bufferIndex = 0

  vertexDesc.layouts[0].stride = 24
  vertexDesc.layouts[0].stepFunction = .perVertex

  let pipelineDesc = MTLRenderPipelineDescriptor()
  pipelineDesc.vertexFunction = vf
  pipelineDesc.fragmentFunction = ff
  pipelineDesc.vertexDescriptor = vertexDesc

  guard let pf = MTLPixelFormat(rawValue: UInt(pixelFormat)) else { return nil }
  pipelineDesc.colorAttachments[0].pixelFormat = pf

  guard let pipeline = try? dev.makeRenderPipelineState(descriptor: pipelineDesc) else {
    return nil
  }

  return OpaquePointer(Unmanaged.passRetained(pipeline).toOpaque())
}

// MARK: Renderpass Descriptor management
@_cdecl("metal_create_render_pass_descriptor")
public func metal_create_render_pass_descriptor() -> OpaquePointer? {
  let passDescriptor = MTLRenderPassDescriptor()

  return OpaquePointer(Unmanaged.passRetained(passDescriptor).toOpaque())
}

@_cdecl("metal_render_pass_set_color_attachment")
public func metal_render_pass_set_color_attachment(
  desc: OpaquePointer,
  texture: OpaquePointer,
  loadAction: UInt64,
  storeAction: UInt64,
  r: Double,
  g: Double,
  b: Double,
  a: Double
) {
  let renderPass = Unmanaged<MTLRenderPassDescriptor>.fromOpaque(UnsafeRawPointer(desc))
    .takeUnretainedValue()
  let tex = Unmanaged<MTLTexture>.fromOpaque(UnsafeRawPointer(texture)).takeUnretainedValue()

  if let attachment = renderPass.colorAttachments[0],
    let load = MTLLoadAction(rawValue: UInt(loadAction)),
    let store = MTLStoreAction(rawValue: UInt(storeAction))
  {
    attachment.texture = tex
    attachment.loadAction = load
    attachment.storeAction = store
    attachment.clearColor = MTLClearColor(
      red: r,
      green: g,
      blue: b,
      alpha: a
    )
  }
}

// MARK: Render Encoding
@_cdecl("metal_command_buffer_create_render_encoder")
public func metal_command_buffer_create_render_encoder(
  buffer: OpaquePointer, descriptor: OpaquePointer
) -> OpaquePointer? {
  let buf = Unmanaged<MTLCommandBuffer>.fromOpaque(UnsafeRawPointer(buffer)).takeUnretainedValue()
  let desc = Unmanaged<MTLRenderPassDescriptor>.fromOpaque(UnsafeRawPointer(descriptor))
    .takeUnretainedValue()
  guard let encoder = buf.makeRenderCommandEncoder(descriptor: desc) else {
    return nil
  }

  return OpaquePointer(Unmanaged.passRetained(encoder).toOpaque())
}

@_cdecl("metal_set_pipeline_state")
public func metal_set_pipeline_state(encoder: OpaquePointer, state: OpaquePointer) {
  let enc = Unmanaged<MTLRenderCommandEncoder>.fromOpaque(UnsafeRawPointer(encoder))
    .takeUnretainedValue()
  let pipeState = Unmanaged<MTLRenderPipelineState>.fromOpaque(UnsafeRawPointer(state))
    .takeUnretainedValue()

  enc.setRenderPipelineState(pipeState)
}

@_cdecl("metal_render_encoder_set_vertex_buffer")
public func metal_render_encoder_set_vertex_buffer(
  encoder: OpaquePointer, buffer: OpaquePointer,
  offset: UInt64, index: UInt64
) {
  let enc = Unmanaged<MTLRenderCommandEncoder>.fromOpaque(UnsafeRawPointer(encoder))
    .takeUnretainedValue()
  let buf = Unmanaged<MTLBuffer>.fromOpaque(UnsafeRawPointer(buffer))
    .takeUnretainedValue()

  enc.setVertexBuffer(buf, offset: Int(offset), index: Int(index))
}
@_cdecl("metal_render_encoder_draw_primitives")
public func metal_render_encoder_draw_primitives(
  encoder: OpaquePointer, primitiveType: UInt64, vertexStart: UInt64, vertexCount: UInt64
) {
  let enc = Unmanaged<MTLRenderCommandEncoder>.fromOpaque(UnsafeRawPointer(encoder))
    .takeUnretainedValue()
  if let primType = MTLPrimitiveType(rawValue: UInt(primitiveType)) {
    enc.drawPrimitives(
      type: primType, vertexStart: Int(vertexStart),
      vertexCount: Int(vertexCount))
  }
}
@_cdecl("metal_render_encoder_end")
public func metal_render_encoder_end(encoder: OpaquePointer) {
  let enc = Unmanaged<MTLRenderCommandEncoder>.fromOpaque(UnsafeRawPointer(encoder))
    .takeUnretainedValue()
  enc.endEncoding()
}
