# Camera Test Scene

## Overview
Simple test scene to validate camera system implementation (Step 4 of camera roadmap).

## Files Created/Modified

### New Scene File
- `assets/scenes/camera_test.scene` - Dedicated camera testing scene

### Modified Files
- `main.zig` - Added camera controls, switched to camera test scene (old scenes commented out)

## Scene Layout

### Reference Markers (World Space Coordinates)

| Entity | Position | Color | Purpose |
|--------|----------|-------|---------|
| Origin | (0, 0) | Pink/Magenta | World center reference |
| North | (0, 20) | Red | +Y axis marker |
| South | (0, -20) | Red | -Y axis marker |
| East | (30, 0) | Blue | +X axis marker |
| West | (-30, 0) | Blue | -X axis marker |
| NE Corner | (30, 20) | Yellow | World bounds |
| NW Corner | (-30, 20) | Yellow | World bounds |
| SE Corner | (30, -20) | Yellow | World bounds |
| SW Corner | (-30, -20) | Yellow | World bounds |
| Player | (0, 0) | Green | Movable entity |
| Grid Dots | Various | Gray | Culling test markers |

## Controls

### Camera Controls (Arrow Keys + Q/E/R)
- **Arrow Keys**: Pan camera smoothly
  - Up: Camera moves up (world appears to move down)
  - Down: Camera moves down (world appears to move up)
  - Left: Camera moves left (world appears to move right)
  - Right: Camera moves right (world appears to move left)
- **Q**: Zoom in (0.9x orthoSize = 10% closer)
- **E**: Zoom out (1.1x orthoSize = 10% farther)
- **R**: Reset camera to origin (0, 0) with default zoom (orthoSize 10.0)

### Player Controls (WASD)
- **W**: Move player up
- **S**: Move player down
- **A**: Move player left
- **D**: Move player right

*Player movement is independent of camera - demonstrates difference between camera and entity movement.*

## What to Test

### Test 1: Camera Panning
1. Press **Arrow Up** - world moves down, origin marker goes toward bottom
2. Press **Arrow Right** - world moves left, origin marker goes toward left
3. Press **R** - camera resets, origin returns to center ✓

### Test 2: Camera Zoom
1. Press **Q** multiple times - entities appear larger, see less world
2. Markers at edges disappear as world "zooms in" ✓
3. Press **E** multiple times - entities appear smaller, see more world
4. More markers become visible ✓
5. Press **R** - zoom resets to default ✓

### Test 3: Player vs Camera Movement
1. Press **W** (player moves) - green circle moves up in world
2. Press **Arrow Up** (camera moves) - entire world moves down, including player
3. These are independent! Player WASD = entity movement, Arrows = camera movement ✓

### Test 4: Coordinate System Verification
1. Camera at (0, 0) - pink origin should be at screen center ✓
2. Camera at (10, 0) - pink origin should be left of center ✓
3. Camera at (0, 10) - pink origin should be below center ✓
4. Math check: camera moved right → world appears left ✓

### Test 5: Zoom Math Verification
1. Default orthoSize 10.0 - see approximately ±13 horizontal, ±10 vertical
2. After 5x Q press (0.9^5 ≈ 0.59) - orthoSize ≈ 5.9, see half as much world
3. After 5x E press (1.1^5 ≈ 1.61) - orthoSize ≈ 16.1, see 1.6x as much world
4. Check with debug system: inspect camera orthoSize value matches expectation ✓

### Test 6: Culling Preparation (Future)
1. Pan camera far right (past x=30) - west markers disappear
2. Pan camera far up (past y=20) - south markers disappear
3. Grid dots at edges appear/disappear as camera moves
4. This is *currently rendering everything*, culling comes in Step 6
5. But validates that transform math is correct for culling system

## Expected Behavior

### Camera at Default (0, 0) with orthoSize 10.0
- Screen center shows pink origin marker
- All 4 edge markers visible (north/south/east/west)
- All 4 corner markers visible
- Green player at screen center (also at world origin)

### After Panning Camera Right (e.g., position 15, 0)
- Pink origin appears left of screen center (at world 0, camera at 15)
- West marker more centered, east marker off-screen
- World "shifts left" visually (camera moved right)

### After Zooming In (e.g., orthoSize 5.0)
- Entities appear 2x larger
- See less world area
- Only entities near camera visible
- Edge markers may be off-screen

### After Zooming Out (e.g., orthoSize 20.0)
- Entities appear 2x smaller
- See more world area
- More entities fit on screen
- Can see farther extent markers

## Debugging Tips

### If Camera Doesn't Move
- Check: `game.translateActiveCamera()` is being called
- Check: Camera entity exists in debug system
- Check: Camera Transform.position is changing
- Check: RenderContext.camera_loc is being updated

### If Zoom Doesn't Work
- Check: `game.zoomActiveCamera()` is being called
- Check: Camera.ortho_size is changing in debug system
- Check: RenderContext.ortho_size is being updated
- Check: orthoSize not clamped to minimum (should allow > 0.1)

### If Direction is Inverted
- Camera moves right, world should appear left ✓
- Camera moves up, world should appear down ✓
- If opposite: check sign in worldToClipSpace subtraction

### If Everything is Off-Screen
- Check: orthoSize not zero (would cause divide by zero)
- Check: Camera position not at extreme value (999999, 999999)
- Check: RenderContext camera data matches Camera component

## Success Criteria

✅ Arrow keys smoothly pan camera
✅ Q/E zoom in/out with visual feedback
✅ R resets camera to expected state
✅ WASD moves player independently of camera
✅ Origin marker position matches camera position inverse
✅ Zoom level matches expected orthoSize values
✅ No visual glitches or artifacts during movement
✅ Text/UI stays readable (will be fixed in Step 5 for true screen-space UI)

## Restore Original Scenes

To switch back to action test scene:
```zig
// In main.zig, comment out camera scene:
// try game.loadScene("camera", "camera_test.scene");
// try game.setActiveScene("camera");

// Uncomment action scene:
try game.loadScene("action", "action_test.scene");
try game.setActiveScene("action");
```

## Next Steps After Validation

Once camera controls work correctly:
- **Step 5**: Implement screen-space UI (text stays fixed while world moves)
- **Step 6**: Implement viewport culling (don't render off-screen entities)
- **Step 7-11**: Debug grids, camera bounds viz, follow system, multi-scene support

