const std = @import("std");
const assets = @import("assets");
const AssetManager = assets.AssetManager;
const math = @import("math");
const WorldPoint = math.WorldPoint;
const ScreenPoint = math.ScreenPoint;
const ecs = @import("ecs");
const Camera = ecs.Camera;
const Destroy = ecs.Destroy;
const Entity = ecs.Entity;
const Sprite = ecs.Sprite;
const Text = ecs.Text;
const Transform = ecs.Transform;
const UIElement = ecs.UIElement;
const World = ecs.World;
const ZxlSprite = ecs.ZxlSprite;
const rend = @import("renderer");
const RenderContext = rend.RenderContext;
const Renderer = rend.Renderer;
const ShapeRegistry = rend.ShapeRegistry;
const shapes = rend.Shapes;
const log = @import("debug").log;

pub fn run(
    renderer: *Renderer,
    world: *World,
    asset_manager: *AssetManager,
    active_camera: Entity,
    dt: f32,
    logical_width: u32,
    logical_height: u32,
) ?RenderContext {
    const camera_loc = world.getComponent(active_camera, Transform) orelse return null;
    const camera = world.getComponent(active_camera, Camera) orelse return null;

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
            renderer.render(
                .{
                    .shape = geo,
                    .transform = .{
                        .offset = transform.position,
                        .rotation = transform.rotation,
                        .scale = transform.scale,
                    },
                    .style = .{
                        .fill = sprite.fill_color,
                        .stroke = sprite.stroke_color,
                        .stroke_width = sprite.stroke_width,
                    },
                    .space = sprite.space,
                },
                if (sprite.space == .screen) ui_ctx else ctx,
            );
        }
    }

    var text_query = world.query(.{ Transform, Text });
    while (text_query.next()) |entry| {
        const transform = entry.get(0);
        const text = entry.get(1);

        const font = asset_manager.getFont(text.font_name) orelse
            asset_manager.getFont("__default__") orelse {
            log.warn(
                .assets,
                "Text font '{s}' missing, no default",
                .{text.font_name},
            );
            continue;
        };

        const offset = text.alignOffsetX(font.measureText(text.text, text.size).x);

        renderer.drawText(
            font,
            text.text,
            .{
                .x = transform.position.x + offset,
                .y = transform.position.y,
            },
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
            const screen_pos = anchor_pos.add(ui_element.offset);

            // Create transform for positioning the UI element
            const ui_transform = rend.Transform{
                .offset = screen_pos,
                .rotation = null,
                .scale = null,
            };

            renderer.render(
                .{
                    .shape = geo,
                    .transform = ui_transform,
                    .style = .{
                        .fill = sprite.fill_color,
                        .stroke = sprite.stroke_color,
                        .stroke_width = sprite.stroke_width,
                    },
                    .space = sprite.space,
                },
                if (sprite.space == .screen) ui_ctx else ctx,
            );
        }
        count += 1;
    }

    var ui_text_query = world.query(.{ UIElement, Text });
    while (ui_text_query.next()) |entry| {
        const ui_element = entry.get(0);
        const text = entry.get(1);
        const font = asset_manager.getFont(text.font_name) orelse
            asset_manager.getFont("__default__") orelse {
            log.warn(
                .assets,
                "Text font '{s}' missing, no default",
                .{text.font_name},
            );
            continue;
        };
        const anchor_pos = rend.getAnchorPos(ui_element.anchor, ui_ctx);
        const screen_pos = WorldPoint{
            .x = anchor_pos.x + ui_element.offset.x,
            .y = anchor_pos.y + ui_element.offset.y,
        };
        renderer.drawTextScreen(
            font,
            text.text,
            ScreenPoint{ .x = screen_pos.x, .y = screen_pos.y },
            text.size,
            text.text_color,
            ui_ctx,
        );
    }

    var zxl_query = world.query(.{ Transform, ZxlSprite });
    while (zxl_query.next()) |entry| {
        const transform: *const Transform = entry.get(0);
        const zxl_sprite: *ZxlSprite = entry.get(1);

        if (!zxl_sprite.visible) continue;

        const zxl_asset = asset_manager.getZxlAsset(zxl_sprite.asset_name) orelse continue;
        const frame_count = zxl_asset.image.frames.items.len;
        const frame = zxl_asset.image.getFrame(zxl_sprite.current_frame) orelse continue;

        // Advance animation if playing and has multiple frames
        if (zxl_sprite.playing and frame_count > 1) {
            zxl_sprite.elapsed_ms += dt * 1000.0;
            if (zxl_sprite.elapsed_ms >= @as(f32, @floatFromInt(frame.duration_ms))) {
                zxl_sprite.elapsed_ms -= @as(f32, @floatFromInt(frame.duration_ms));
                zxl_sprite.current_frame = @intCast((zxl_sprite.current_frame + 1) % frame_count);
            }
        }

        // Get or lazily create GPU texture for this frame
        const texture = asset_manager.getOrCreateFrameTexture(
            zxl_asset,
            zxl_sprite.current_frame,
        ) catch continue;

        // Compute world-space dimensions from pixel size
        const world_width = @as(f32, @floatFromInt(frame.width)) * zxl_sprite.pixel_scale;
        const world_height = @as(f32, @floatFromInt(frame.height)) * zxl_sprite.pixel_scale;

        // Normalized origin from frame's pixel origin
        const origin = [2]f32{
            @as(f32, @floatFromInt(frame.origin_x)) / @as(f32, @floatFromInt(frame.width)),
            @as(f32, @floatFromInt(frame.origin_y)) / @as(f32, @floatFromInt(frame.height)),
        };

        renderer.drawTextureQuad(
            texture,
            world_width,
            world_height,
            origin,
            .{ .offset = transform.position, .rotation = transform.rotation, .scale = transform.scale },
            ctx,
            zxl_sprite.flip_h,
            zxl_sprite.flip_v,
        );
    }

    return ctx;
}
