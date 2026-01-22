const std = @import("std");
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
const UIElement = ecs.UIElement;
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
    logical_width: u32,
    logical_height: u32,
) void {
    const camera_loc = world.getComponent(active_camera, Transform) orelse return;
    const camera = world.getComponent(active_camera, Camera) orelse return;

    // Context for world-space rendering (uses scaled/physical dimensions)
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

    // Context for screen-space UI rendering (uses logical dimensions)
    const ui_ctx: RenderContext = .{
        .camera_loc = camera_loc.position,
        .delta_time = dt,
        .frame_number = 0,
        .ortho_size = camera.ortho_size,
        .height = logical_height,
        .width = logical_width,
        .scale_factor = 1.0,
        .time = 0,
    };

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
    var count: usize = 0;
    var ui_query = world.query(.{ UIElement, Sprite });
    while (ui_query.next()) |entry| {
        const ui_element: *const UIElement = entry.get(0);
        const sprite: *Sprite = entry.get(1);
        const geo = sprite.geometry orelse continue;

        if (sprite.visible) {
            // Calculate anchor position in screen space
            const anchor_pos = rend.getAnchorPos(ui_element.anchor, ui_ctx);

            // Apply offset from anchor
            const screen_pos = WorldPoint{
                .x = anchor_pos.x + ui_element.offset.x,
                .y = anchor_pos.y + ui_element.offset.y,
            };

            // Create transform for positioning the UI element
            const ui_transform = rend.Transform{
                .offset = screen_pos,
                .rotation = null,
                .scale = null,
            };

            renderer.drawGeometry(
                geo,
                ui_transform,
                sprite.fill_color,
                sprite.stroke_color,
                sprite.stroke_width,
                ui_ctx,
            );
        }
        count += 1;
    }

    debugger.run(dt, ctx);
}
