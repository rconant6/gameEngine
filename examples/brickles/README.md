# Brickles

A breakout clone built as the engine's **acceptance test**: a complete game expressed
as scene files + templates + a thin `main.zig`, with **zero engine modifications**.

Run it: `zig build brickles`
Headless smoke test: `BRICKLES_SELFTEST=1 ./zig-out/bin/brickles` (drives the whole
loop without a window and asserts the wiring — useful in CI).

## Mechanic → engine feature

| Brickles mechanic | How it's expressed | Where |
|---|---|---|
| Paddle moves while arrow held, stops on release | `OnInput` held/released → `set_velocity` | brickles.scene |
| Ball bounces off walls/paddle/bricks | `OnCollision` → `bounce` (normal-aware + separation) | brickles.scene |
| Brick dies on hit, +score, brick count-- | `OnCollision ball` → `add_state_int{score}` + `add_state_int{bricks,-1}` + `destroy_self` (3 actions, one trigger) | bricks.template |
| Ball past paddle → lose a ball, re-serve | gutter `OnCollision ball` → `add_state_int{balls,-1}` + `transition_state serve` | brickles.scene |
| SCORE / BALLS HUD, live | `Text` + `StateText` bound to state vars | brickles.scene |
| attract / serve / playing / win / lose screens | `StateDescriptor.scene` binding + `stateEntered` | main.zig + *.scene |
| Win (bricks==0) / lose (balls==0) | main loop checks state vars → `transitionTo` | main.zig |
| "Press space" restarts | `restartGame` | main.zig |

`main.zig` only orchestrates: declare states, serve/launch the ball, detect win/lose,
build the brick grid. All gameplay rules live in scene/template data.

## Multi-level (the stress test)

5 levels of rising difficulty, driven by a `level` state var:
- **More bricks** — +1 row per level (L1=3 rows/27 bricks … L5=7 rows/63 bricks).
- **Faster ball** — `11 + (level-1)*2` units/s, read in `launchBall`.
- **Different palette** — each level themes its rows from a different mix of the 6
  brick color templates (cyan/gold/green/orange/red/purple), churning several
  distinct templates through the instantiator.
- **Flow** — clearing a level (`bricks==0`) bumps `level` and re-serves the next,
  harder board; clearing the final level → the win screen. `level`/`score` survive
  level-to-level (plain transition); `restart_game` wipes them for a new game.

This exercises what a single level can't: repeated full-playfield instantiate/
destroy cycles (the 7C free-list under churn — `selftest.zig` hammers 50× build/
teardown of the 63-brick grid and asserts exact counts each time), state-driven
difficulty, and a `win` that loops back to play rather than ending.

## Frictions found (the point of this exercise)

1. **No scene-level template instantiation.** The DSL can declare a template and
   define entities, but can't say "place template Brick at these N positions." So the
   brick grid's *placement* had to move into a `main.zig` loop calling
   `world.createEntityFromTemplate` — the brick's look/behavior stays pure-DSL
   (bricks.template), only the layout is in Zig. A `[spawn template=Brick at=...]` or
   grid directive would keep layout declarative.

2. **`loadTemplates` path needs a trailing slash.** It concatenates `dir + filename`
   with no separator, so `"assets/templates"` silently yields `FileNotFound` while
   `"assets/templates/"` works. Undocumented sharp edge; should normalize or use a path join.

3. **"Rebuild bricks on new game, not on re-serve" can't key off the counter var.**
   The `bricks` state var is initialized before any brick entities exist, so it can't
   distinguish a fresh game from a re-serve. Solved by checking for actual brick
   *entities* (`findEntityByTag("brick") == null`) instead — works, but it's a subtlety
   a beginner would trip on.

4. **No centered/anchored world-space text.** All screen text is left-anchored from its
   Transform, so every title/prompt has a hand-tuned negative-x nudge. (Known; tracked
   as a 6A follow-up.)

5. **Collision triggers are level-triggered, not edge-triggered (the big one).**
   An `OnCollision` action fires *every frame the shapes overlap*, not once on
   contact. Fine for `bounce` (it self-separates), but catastrophic for
   `add_state_int` / `transition_state`: the gutter's "lose a ball + re-serve"
   trigger fired ~11× per ball-crossing, draining `balls` to negative and
   re-serving in a storm — this is what crashed live play. Worked around by
   removing the gutter `OnCollision` and edge-detecting the ball crossing the
   gutter line once in `main.zig` (`ballBelowGutter`). A real fix needs a
   fire-once-on-enter collision semantic in the engine (an `OnCollisionEnter`, or
   a per-trigger debounce). This is the single most important finding — any
   counter/transition driven by collision hits the same trap.

6. **No "solid collider" that blocks movement.** Collision detection only
   *reports* overlaps; only `bounce` reacts to them. So the paddle (collider, no
   bounce) slides straight through the side walls — and `parkBall` then spawns the
   ball at the paddle's now-off-field x, outside the play area. Pong worked around
   this with a `clampPaddleVelocity` in main.zig; Brickles needs the same paddle
   clamp (not yet added — known open bug). A teen expects "this wall is solid" to
   just work; a static/blocking collider primitive would close this.

7. **(Engine bug, flagged not fixed)** `TemplateManager.loadTemplatesFromDirectory`
   (`src/scene/templates.zig:138`) has both an `errdefer` and a `defer` freeing
   `full_path` → double-free on the `loadTemplateFile` error path.
