# Revision 02 browser review

FAIL_ART_ASSEMBLY. Actual loopback Chromium replay and explicit paused release progress .5/.75 were inspected, with three original browser screenshots saved in playback02.

The large rectangular shoulder patch is gone. Release .5 still has a pointed shoulder contour and a sleeve that appears attached as a block rather than continuous clothing. White-background .75 reveals fine triangle-edge cracks across even the rigid head and legs. These are independent Canvas triangle-clip antialias seams and are a renderer defect, not evidence that the atlas contains a grid.

Revision 03 now uses one shared-edge WebGL triangle batch per deforming mesh, with premultiplied alpha and normal shared-edge rasterization. The head is drawn as one rigid source crop and the hand/brush remains a rigid image. Existing semantic occlusion clips and motion are retained. No new artwork or gameplay changes. JavaScript syntax checked; revision 03 still needs actual browser rendering and animation review. The shoulder contour problem is not claimed fixed by this rasterization change.
