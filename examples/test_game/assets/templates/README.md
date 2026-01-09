# Entity Templates

This directory contains entity template definitions for testing the `spawn_entity` action.

## Template Categories

### Ship Templates (`ship.template`)
- **PlayerShip** - Main player ship translated from zasteroids
  - Note: Original had 8 separate shapes (hull, cockpit, wings, engine, flames)
  - Current version provides hull only due to single-Sprite-per-entity limitation
  - Scale: 1.0, No initial velocity

### Asteroid Templates (`asteroids.template`)
- **LargeAsteroid** - Large asteroid with 12-point polygon
  - Scale: 35.0, Velocity: (0.5, 0.15), Angular: 0.2
  - Original score: 50 points

- **MediumAsteroid** - Medium asteroid with 10-point polygon
  - Scale: 28.0, Velocity: (0.5, 0.15), Angular: 0.1
  - Original score: 100 points

- **SmallAsteroid** - Small asteroid with 8-point polygon
  - Scale: 20.0, Velocity: (0.5, -0.25), Angular: 0.5
  - Original score: 200 points

### Projectile Templates (`projectiles.template`)
- **Missile** - Yellow circle, medium speed (-500), 2s lifetime
- **Bullet** - Red circle, fast speed (-800), 1.5s lifetime
- **Laser** - Cyan rectangle, very fast (-1000), 1s lifetime

### Enemy Templates (`enemies.template`)
- **BasicEnemy** - Red circle, slow movement
- **FastEnemy** - Orange circle, diagonal fast movement
- **TankEnemy** - Dark red rectangle, very slow/tanky
- **Boss** - Large indigo octagon, horizontal movement

### Effect Templates (`effects.template`)
- **ExplosionParticle** - Small orange particle, 0.5s lifetime
- **SmallExplosion** - Orange burst, 0.3s lifetime
- **LargeExplosion** - Red/gold burst, 0.8s lifetime
- **Debris** - Gray rectangle, tumbling motion
- **Spark** - Bright yellow flash, 0.2s lifetime

### Powerup Templates (`powerups.template`)
- **HealthPowerup** - Green circle
- **WeaponPowerup** - Red square
- **ShieldPowerup** - Blue circle
- **SpeedBoost** - Yellow diamond

## Translation Notes

### From zasteroids
The original zasteroids templates included:
- Compile-time StaticStringMap structures
- Multiple shapes per entity
- Score values stored in template
- Spawn config with min/max velocity ranges

### Current Implementation Differences
- Templates are runtime-loaded from .scene files
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
