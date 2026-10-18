# Front continuous rig 01: unaccepted assembly

New implementation, not recovered production code. No game source changed, no Sim or Godot executed.

- Stable head/face pixels from the original neutral image are moved rigidly.
- Chest/waist and original left arm have a bounded continuous counterbalancing field.
- One complete right sleeve uses a continuous 32x32 UV mesh, shoulder-to-wrist affine mapping plus a radial twist around the cuff.
- Hand and complete brush share one rigid transform; shaft length is never deformed. The generated extra cuff is excluded by a semantic clip polygon; actual wrist overlap still needs inspection.
- A locally sampled clothing patch fills the old right-arm removal region. The original texture is not edited. Hole coverage, old fragments, seams and layering remain unverified.
- Neutral pants use the previously inspected independent continuous lower mesh.
- Replay draw/hold are illustrative input intervals. Release uses the recovered original .6000000238418579 clip span. This does not commit gameplay or synthesize a release event.

A first curved-tube sleeve mapping produced nonpositive sampled areas and was rejected before browser rendering. The current radial-twist field has 303 sampled poses x2048 triangles with no nonpositive triangles, minimum signed double area4.168. This is a numerical sample, not a continuous-domain proof or art acceptance.

Required actual observations: neutral body patch and sleeve-root coverage; wrist/cuff overlap; brush completeness; torso/head continuity; left balance; no inverted or stretched sleeve texture at maximal reach; 240px and60px playback; idle return while lower legs keep moving. Existing world effects and game state are outside this prototype.

## Revision 02 after actual playback
Revision 01 failed visual assembly: a rectangular shoulder patch and hard sleeve root were visible in the loopback browser replay. Its exact JavaScript and sleeve sample result are retained in history01.

Revision 02 narrows the removed arm polygon to preserve the original shoulder cap. The fill is a mapped small torso-contour polygon instead of a rectangular external patch. One continuous sleeve is composited behind the shoulder, with its distal portion drawn in front for chest crossing; both use the identical deformation. Chest/head weight shift and opposite-arm balance are increased, while the head remains rigid. The 303-pose sleeve triangle sampling remains positive. This revision has not yet been visually replayed and is not accepted art. Canvas triangle-edge raster seams also need checking in the next actual preview.
