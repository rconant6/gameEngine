# Entity Templates

This directory contains entity template definitions for the `spawn_entity` action.

## Template Format

Templates use the same syntax as scene files but with `:template` suffix instead of `:entity`:

```
[TemplateName:template]
  [ComponentName]
    field:type value
  [ComponentName:variant]
    field:type value
```

## Supported Components

### Core Components
- **Transform** - Position, rotation, scale
  - `position:vec3` or `position:vec2` (z defaults to 0)
  - `rotation:f32` (radians)
  - `scale:f32`

- **Velocity** - Linear and angular motion
  - `linear:vec2 {x, y}`
  - `angular:f32` (radians per second)

- **Tag** - String tags for identification/filtering
  - `tags:string "tag1,tag2,tag3"` (comma-separated)

- **Lifetime** - Auto-destroy timer
  - `remaining:f32` (seconds)

### Sprite Variants
- **Sprite:circle**
  - `origin:vec2`, `radius:f32`
  - `fill_color:color #RRGGBB`, `stroke_color:color`, `stroke_width:f32`

- **Sprite:rectangle**
  - `center:vec2`, `half_width:f32`, `half_height:f32`
  - `fill_color:color`, `stroke_color:color`, `stroke_width:f32`

- **Sprite:triangle**
  - `v0:vec2`, `v1:vec2`, `v2:vec2`
  - `fill_color:color`, `stroke_color:color`, `stroke_width:f32`

- **Sprite:line**
  - `start:vec2`, `end:vec2`
  - `stroke_color:color`, `stroke_width:f32`

- **Sprite:polygon**
  - `points:vec2[] {{x1,y1}, {x2,y2}, ...}`
  - `fill_color:color`, `stroke_color:color`, `stroke_width:f32`

### Collider Variants
- **Collider:circle** - `radius:f32`
- **Collider:rectangle** - `center:vec2`, `half_width:f32`, `half_height:f32` OR `half_w:f32`, `half_h:f32`

### Behavior Components
- **ScreenWrap** - Wrap around screen edges (no fields)
- **ScreenClamp** - Clamp to screen bounds (no fields)
- **OnCollision** - Collision triggers (action syntax not yet parsed)
- **OnInput** - Input triggers (action syntax not yet parsed)

## Template Categories

### Ship Templates (`ship.template`)
- **PlayerShip** - Main player ship translated from zasteroids
  - Note: Original had 8 separate shapes (hull, cockpit, wings, engine, flames)
  - Current version provides hull only due to single-Sprite-per-entity limitation
  - Scale: 1.0, No initial velocity

### Asteroid Templates (`asteroids.template`)
- **LargeAsteroid** - Large asteroid with 12-point polygon
  - Scale: 35.0, Velocity: (0.5, 0.15), Angular: 0.2
  - Tags: "asteroid,large"

- **MediumAsteroid** - Medium asteroid with 10-point polygon
  - Scale: 28.0, Velocity: (0.5, 0.15), Angular: 0.1
  - Tags: "asteroid,medium"

- **SmallAsteroid** - Small asteroid with 8-point polygon
  - Scale: 20.0, Velocity: (0.5, -0.25), Angular: 0.5
  - Tags: "asteroid,small"

### Projectile Templates (`projectiles.template`)
- **Missile** - Yellow circle, velocity (0, 5), 2s lifetime, collider
  - Tags: "missile,projectile,player_weapon"
- **Bullet** - Red small circle, velocity (0, -800), 1.5s lifetime, collider
  - Tags: "bullet,projectile,player_weapon"
- **Laser** - Cyan rectangle, velocity (0, -1000), 1s lifetime, collider
  - Tags: "laser,projectile,player_weapon"

### Enemy Templates (`enemies.template`)
- **BasicEnemy** - Red circle, slow movement, collider
  - Tags: "enemy,basic"
- **FastEnemy** - Orange circle, diagonal fast movement, collider
  - Tags: "enemy,fast"
- **TankEnemy** - Dark red rectangle, very slow/tanky, collider
  - Tags: "enemy,tank"
- **Boss** - Large indigo octagon, horizontal movement, collider
  - Tags: "enemy,boss"

### Effect Templates (`effects.template`)
- **ExplosionParticle** - Small orange circle, angular velocity, 0.5s lifetime
  - Tags: "particle,explosion,effect"
- **SmallExplosion** - Orange circle with stroke, 0.3s lifetime
  - Tags: "explosion,effect"
- **LargeExplosion** - Large red/gold circle, 0.8s lifetime
  - Tags: "explosion,effect,large"
- **Debris** - Gray rectangle, tumbling motion, screen wrap, 2s lifetime
  - Tags: "debris,particle,effect"
- **Spark** - Bright yellow flash, fast diagonal, 0.2s lifetime
  - Tags: "spark,particle,effect"

### Powerup Templates (`powerups.template`)
- **HealthPowerup** - Green circle, slow drift, 5s lifetime, collider
  - Tags: "powerup,health,collectible"
- **WeaponPowerup** - Red square, slow drift, 5s lifetime, collider
  - Tags: "powerup,weapon,collectible"
- **ShieldPowerup** - Blue circle, slow drift, 5s lifetime, collider
  - Tags: "powerup,shield,collectible"
- **SpeedBoost** - Yellow diamond polygon, fast spin, 5s lifetime, collider
  - Tags: "powerup,speed,collectible"

## Translation Notes

### From zasteroids
The original zasteroids templates included:
- Compile-time StaticStringMap structures
- Multiple shapes per entity
- Score values stored in template
- Spawn config with min/max velocity ranges

### Current Implementation Differences
- Templates are runtime-loaded from .template files
- Single Sprite component per entity (for now)
- Score values would need custom ScoreValue component
- Velocity randomization would be handled by spawner

## Usage (Once Implemented)

Templates will be spawned using the `spawn_entity` action:

```
[Action]
  type:action spawn_entity
  template_name:string "Missile"
  offset:vec2 {0.0, -30.0}
  priority:i32 0
```

The spawner will:
1. Look up template by name
2. Create new entity
3. Copy all components from template
4. Override Transform position with spawn location + offset
5. Return spawned entity

## Testing Plan

1. **Load all templates** at startup
2. **Spawn missiles** via Spacebar input trigger
3. **Spawn explosions** on collision events
4. **Spawn asteroids** to test large polygon rendering
5. **Chain spawns** (asteroid breaks into smaller asteroids)
6. **Verify component copying** (all components present on spawned entities)
7. **Test lifetime cleanup** (entities auto-destroy at end of lifetime)

## Future Enhancements

- Template inheritance (extend base templates)
- Multi-shape entities (composite entities with child sprites)
- Randomization metadata (velocity ranges, color variations)
- Template hot-reloading
- Template validation on load
