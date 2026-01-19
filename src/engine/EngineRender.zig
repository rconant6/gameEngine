const Engine = @import("../engine.zig").Engine;
const core = @import("math");
const ShapeRegistry = core.ShapeRegistry;
const renderer = @import("renderer");
const RenderTransform = renderer.Transform;

pub fn draw(self: *Engine, shape: anytype, xform: ?RenderTransform) void {
    const T = @TypeOf(shape);
    const shape_union = ShapeRegistry.createShapeUnion(T);
    self.renderer.drawShape(shape_union, xform);
}
