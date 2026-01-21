const assets = @import("assets");
const AssetManager = assets.AssetManager;
const math = @import("math");
const WorldPoint = math.WorldPoint;
const db = @import("debug");
const DebugManager = db.DebugManager;
const ecs = @import("ecs");
const Camera = ecs.Camera;
const Destroy = ecs.Destroy;
const Entity = ecs.Entity;
const Sprite = ecs.Sprite;
const Text = ecs.Text;
const Transform = ecs.Transform;
const World = ecs.World;
const rend = @import("renderer");
const RenderContext = rend.RenderContext;
const Renderer = rend.Renderer;
const ShapeRegistry = rend.ShapeRegistry;
const shapes = rend.Shapes;

pub fn run(
    renderer: *Renderer,
    world: *World,
    asset_manager: *AssetManager,
    active_camera: Entity,
    dt: f32,
    debugger: *DebugManager,
) void {
    const camera_loc = world.getComponent(active_camera, Transform) orelse return;
    const camera = world.getComponent(active_camera, Camera) orelse return;
    const ctx: RenderContext = .{
        .camera_loc = camera_loc.position,
        .delta_time = dt,
        .frame_number = 0,
        .ortho_size = camera.ortho_size,
        .height = renderer.height,
        .width = renderer.width,
        .scale_factor = 1.0,
        .time = 0,
    };

    var text_query = world.query(.{ Transform, Text });
    while (text_query.next()) |entry| {
        const transform = entry.get(0);
        const text = entry.get(1);

        const font = asset_manager.getFont(text.font_asset) orelse continue;

        renderer.drawText(
            font,
            text.text,
            transform.position,
            text.size,
            text.text_color,
            ctx,
        );
    }
    var query = world.query(.{ Transform, Sprite });
    while (query.next()) |entry| {
        const transform = entry.get(0);
        const sprite = entry.get(1);
        const geo = sprite.geometry orelse continue;

        if (sprite.visible) {
            renderer.drawGeometry(
                geo,
                .{
                    .offset = transform.position,
                    .rotation = transform.rotation,
                    .scale = transform.scale,
                },
                sprite.fill_color,
                sprite.stroke_color,
                sprite.stroke_width,
                ctx,
            );
        }
    }
    debugger.run(dt, ctx);
}
