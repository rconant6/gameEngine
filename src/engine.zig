// ============================================================================
// Engine Library - Public API
// ============================================================================

// MARK: Engine Struct
const engine = @import("engine/engine.zig");
pub const Engine = engine.Engine;

// MARK: Platform Types
const platform = @import("platform");
pub const KeyCode = platform.KeyCode;
pub const KeyModifiers = platform.KeyModifiers;
pub const MouseButton = platform.MouseButton;
pub const Input = platform.Input;

// MARK: Math Types
const math = @import("math");
pub const V2 = math.V2;
pub const V2I = math.V2I;
pub const V2U = math.V2U;
pub const WorldPoint = V2;
pub const ScreenPoint = V2I;

// MARK: Renderer Types
const renderer = @import("renderer");
pub const Color = renderer.Color;
pub const Colors = renderer.Colors;
pub const Circle = renderer.Shapes.Circle;
pub const Rectangle = renderer.Shapes.Rectangle;
pub const Triangle = renderer.Shapes.Triangle;
pub const Polygon = renderer.Shapes.Polygon;
pub const Line = renderer.Shapes.Line;
pub const RenderContext = renderer.RenderContext;
pub const RenderTransform = renderer.Transform;
pub const ShapeRegistry = renderer.ShapeRegistry;

// MARK: Asset Types
const assets = @import("assets");
pub const FontHandle = assets.FontHandle;
pub const Font = assets.Font;

// MARK: ECS Types
const ecs = @import("ecs");
pub const ActiveCamera = ecs.ActiveCamera;
pub const Camera = ecs.Camera;
pub const CameraTracking = ecs.CameraTracking;
pub const Collider = ecs.Collider;
pub const ColliderShape = ecs.ColliderShape;
pub const ColliderRegistry = ecs.ColliderRegistry;
pub const ComponentRegistry = ecs.ComponentRegistry;
pub const Collision = ecs.Collision;
pub const Destroy = ecs.Destroy;
pub const Entity = ecs.Entity;
pub const Lifetime = ecs.Lifetime;
pub const OnCollision = ecs.OnCollision;
pub const OnInput = ecs.OnInput;
pub const Physics = ecs.Physics;
pub const RenderLayer = ecs.RenderLayer;
pub const Sprite = ecs.Sprite;
pub const Tag = ecs.Tag;
pub const Text = ecs.Text;
pub const TrackingMode = ecs.TrackingMode;
pub const Transform = ecs.Transform;
pub const UIElement = ecs.UIElement;
pub const Velocity = ecs.Velocity;
pub const World = ecs.World;

// MARK: Action Types
const action = @import("action");
pub const Action = action.Action;
pub const ActionSystem = action.ActionSystem;
pub const CollisionTrigger = action.CollisionTrigger;
pub const InputTrigger = action.InputTrigger;
pub const TriggerContext = action.TriggerContext;

// MARK: Scene Types
const scene = @import("scene");
pub const Instantiator = scene.Instantiator;
pub const SceneManager = scene.SceneManager;
pub const Template = scene.Template;
pub const TemplateManager = scene.TemplateManager;

// MARK: Debug Types
const debug = @import("debug");
pub const DebugCategory = debug.DebugCategory;
pub const Debugger = debug.DebugManager;
