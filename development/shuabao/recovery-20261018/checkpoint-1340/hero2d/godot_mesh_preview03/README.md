# Detached front mesh preview

New implementation for actual Godot GPU rasterization. No game project, Sim, damage, skill effects, or source actor is instantiated. Browser revisions 01/02 failed shoulder assembly; revision 03 could not obtain WebGL in the cloud browser. These failures remain evidence, not prior passes.

The six-file runtime closure is project.godot, main.tscn, preview.gd and three original PNGs copied byte-for-byte from ../front_rig01 into the fresh project root. Texture creation uses Image.load and ImageTexture; no imported game tree is needed. Runtime should use its approved normal-window wrapper and external bounded guard, never headless. Pass --output=/absolute/fresh/directory. No engine was run during authoring.

Six fixed keys each receive three actual frame_post_draw observations, then a 7.6-second continuous replay runs idle/draw/hold/release/return twice. The .6000000238418579 release segment preserves the recovered source clip span. Other replay intervals are authored demonstration choices, not Sim timing or gameplay evidence. All three characters share upper pose while the latter two have independently moving lower meshes (240/60 pixels).

Original rigid head is a two-triangle rigid quad; full sleeve and torso are continuous ArrayMesh surfaces. Hand/brush is one rigid textured polygon. The sleeve is one geometry instance used with root-behind-body and distal-in-front occlusion; source UV masks preserve the original atlas. Shared GPU rasterization replaces Canvas clip cracks. Every candidate mesh is checked before assignment for finite vertices and positive triangle areas. No pose is accepted after a failed mesh. This does not prove visual quality: the shoulder cap is still a known unresolved pointed/hard contour and must be judged in actual images.

At most 12 original viewport PNGs are retained in bounded 64MiB RAM, with per-draw serial/process/frames_drawn/phase metadata. Internal wall deadline is 15 seconds; failure is exit4. Output directory must be fresh and absolute. Existing output is never written. A final JSON byte readback verifies the small report; PNG write errors also fail. A report accepted field means only that this detached fixture completed, never art or real combat acceptance.

Review points: shoulder contour and sleeve/chest overlap at release .5; cuff/hand connection; brush shaft and tip arc; head/torso joining at y240; white-background absence of triangle grids; waist and shoe shape during walking; 60px readability. No permission or browser GPU setting is changed.

## Parse correction 02
Run 01 failed script parsing at the dictionary-dependent inferred Vector2 h before any internal timer or artwork evidence. This fresh candidate explicitly types all inferred local declarations and lambda arguments/returns. Motion, resource bytes, output rules and deadlines are unchanged. The failed source and stage are preserved. Static typing review is not a successful native parse.

## Shoulder occlusion revision 03
Native02 completed actual GPU rendering; all twelve images were reviewed. Triangle raster cracks are gone. Crossing-chest key03 retains a pointed original shoulder cap and the new sleeve proximal volume is excessively hidden. This revision moves the sleeve shoulder anchor from (145,245) to (135,240) and exposes its continuous proximal segment from source longitudinal t=0 instead of t=.30. The original neutral assets, hand/brush rigid transform, head, torso, gait and phase curve remain unchanged. Actual shoulder appearance is pending review; this is not claimed fixed. The same six continuous-replay screenshots now target release at 2.03/2.16/2.30/2.44/2.56/6.30 seconds instead of redundant idle/hold sampling; frame replay duration and image/RAM limits are unchanged.

Each targeted replay capture must have actual phase release and progress in [0,1); a missed window or incomplete six captures fails explicitly. No idle image can satisfy release coverage.
