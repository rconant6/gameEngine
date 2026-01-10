# Scene Files

This directory contains scene definitions that can be loaded and instantiated by the engine.

## Scene Format

Scenes use a bracket-based syntax with type annotations:

```
[AssetName:asset type]
  field:type value

[SceneName:scene]
  [EntityName:entity]
    [ComponentName]
      field:type value
    [ComponentName:variant]
      field:type value
```

## Supported Types

### Value Types
- **bool** - `true` or `false`
- **i32** - 32-bit signed integer
- **f32** - 32-bit float
- **string** - Quoted string `"text"`
- **color** - Hex color `#RRGGBB` or `#RRGGBBAA`
- **vec2** - 2D vector `{x, y}`
- **vec3** - 3D vector `{x, y, z}`
- **vec2[]** - Array of vec2 `{{x1,y1}, {x2,y2}, ...}`
- **asset_ref** - Reference to asset `"AssetName"`

### Asset Types
- **asset font** - Font asset
  - `path:string` - Directory path (optional)
  - `filename:string` - Font filename
  - `abs_path:string` - Absolute path (alternative)

## Supported Components

### Core Components
- **Transform** - Position, rotation, scale
  - `position:vec3` or `position:vec2` (z defaults to 0)
  - `rotation:f32` (radians, optional, default 0)
  - `scale:f32` (optional, default 1.0)

- **Velocity** - Linear and angular motion
  - `linear:vec2 {x, y}`
  - `angular:f32` (radians per second)

- **Tag** - String tags for identification/filtering
  - `tags:string "tag1,tag2,tag3"` (comma-separated)

- **Lifetime** - Auto-destroy timer
  - `remaining:f32` (seconds)

- **Camera** - Camera configuration
  - `fov:f32` (field of view in degrees)
  - `near:f32` (near clipping plane)
  - `far:f32` (far clipping plane)

### Sprite Variants
All sprites support `visible:bool` (default true)

- **Sprite:circle**
  - `origin:vec2` - Circle center offset
  - `radius:f32` - Circle radius
  - `fill_color:color` (optional)
  - `stroke_color:color` (optional)
  - `stroke_width:f32` (required if stroke_color present)

- **Sprite:rectangle**
  - `center:vec2` - Rectangle center offset
  - `half_width:f32` - Half width
  - `half_height:f32` - Half height
  - `fill_color:color` (optional)
  - `stroke_color:color` (optional)
  - `stroke_width:f32` (required if stroke_color present)

- **Sprite:triangle**
  - `v0:vec2`, `v1:vec2`, `v2:vec2` - Triangle vertices
  - `fill_color:color` (optional)
  - `stroke_color:color` (optional)
  - `stroke_width:f32` (required if stroke_color present)

- **Sprite:line**
  - `start:vec2`, `end:vec2` - Line endpoints
  - `stroke_color:color` (required)
  - `stroke_width:f32` (required)

- **Sprite:polygon**
  - `points:vec2[]` - Polygon vertices `{{x1,y1}, {x2,y2}, ...}`
  - `fill_color:color` (optional)
  - `stroke_color:color` (optional)
  - `stroke_width:f32` (required if stroke_color present)

- **Box** - Simple filled rectangle (legacy/background use)
  - `size:vec2` - Full width and height
  - `fill_color:color`
  - `filled:bool`

### Collider Variants
- **Collider:circle**
  - `radius:f32`

- **Collider:rectangle**
  - `center:vec2`
  - `half_width:f32`, `half_height:f32`
  - Alternative: `half_w:f32`, `half_h:f32`

### Text Rendering
- **Text**
  - `text:string` - Text to display
  - `font_asset:asset_ref` - Reference to font asset
  - `text_color:color` - Text color
  - `size:f32` - Font size

### Behavior Components
- **ScreenWrap** - Wrap around screen edges (no fields)
- **ScreenClamp** - Clamp to screen bounds (no fields)
- **OnCollision** - Collision triggers (action syntax not yet parsed)
- **OnInput** - Input triggers (action syntax not yet parsed)

## Scene Files

### master.scene
Comprehensive rendering test scene showcasing all sprite types and features:
- All sprite variants (circle, rectangle, triangle, line, polygon)
- Fill and stroke rendering
- Motion (linear and angular velocity)
- Screen wrapping and clamping
- Text rendering
- Scale variations

Purpose: Visual regression testing and feature demonstration

### collision_test.scene
Collision detection and physics test scene:
- Moving circles and rectangles
- Static walls
- Screen clamping behavior
- Collision components
- Tags for collision filtering

Purpose: Physics and collision system testing

### action_test.scene
Action system test scene (for future action/trigger implementation):
- Mutual destruction on collision
- Velocity changes on collision
- Entity spawning
- Multi-action sequences
- Tag-based collision filtering
- Debug actions

Purpose: Action/trigger system development and testing

## Asset References

Scenes can reference assets defined either:
1. In the same scene file (above the scene definition)
2. In separate asset files (future feature)

Assets must be defined before they are referenced.

Example:
```
[OrbitronFont:asset font]
  path:string "assets/fonts/"
  filename:string "Orbitron.ttf"

[MyScene:scene]
  [TextEntity:entity]
    [Text]
      font_asset:asset_ref "OrbitronFont"
      text:string "Hello"
```

## Loading Scenes

Scenes are loaded in code using the Engine's scene loading API:

```zig
try game.loadSceneFromFile("assets/scenes/master.scene");
```

The engine will:
1. Parse the scene file
2. Load any referenced assets
3. Instantiate all entities with their components
4. Add entities to the world

## Comments

Use `//` for single-line comments anywhere in the file:

```
// This is a comment
[MyEntity:entity]  // Entity comment
  [Transform]
    position:vec2 {0.0, 0.0}  // Field comment
```

## Future Features

- Scene hot-reloading
- Nested action/trigger syntax parsing
- Multi-scene composition
- Scene variables/parameters
- Asset bundles/packages
- Scene validation tool
