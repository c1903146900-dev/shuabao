# Minion material readability — WIP 01

Source-only candidate. Engine parsing and visual acceptance are pending. This is a local readability experiment, not a claim that the overall art style is complete.

Only the minion actor and eight exact authored material names receive overrides. Unknown materials retain the previous treatment. Other actor kinds keep their original palette, outline parameters and shader arithmetic. The new shader parameter defaults to false. Original damage feedback is applied after the optional form shading.

Armor receives a unified warm midtone and restrained three-level shading; bone plates are less bright, copper fittings darker, and internal joint outlines thinner. The illustration shading is fixed in view space, independent of scene lighting. It needs movement testing for distracting band changes. It does not repair anatomical proportions or remove segmented geometry.

The two files must match the manifest preimage hashes before application. No GLB, skeleton, vertex data, animation, collision, warning, health bar, damage or progression files are included.

## Validation status

Static checks confirm all eight material names exist in the asset metadata. Removing the optional shader branch reproduces the original shader source exactly; removing the new view insertions reproduces the original view source. This establishes source-level default-path equivalence, not pixel-identical GPU output or runtime import-name verification.

## Native comparison plan

1. Capture the original and candidate at the same first-combat viewpoint, viewport size, enemy positions and animation time. Retain full-frame images and unscaled crops of all four minions.
2. Confirm the torso reads as one body before the small fittings, at normal display size. Check that the lower two minions separate from the floor without brighter outlines around every limb segment.
3. Record a short normal movement and turning sequence. Check thin outlines for flicker, three-level shading for popping, and contact feedback for visibility.
4. Exercise existing attack warnings, damage feedback and death. Confirm health, hitboxes, damage values and warning timing remain unchanged.
5. Capture unchanged non-minion enemy types and compare material parameters and images. Include the Boss fallback/ownership path.
6. Verify enable/disable and teardown still restore original surface materials. If authored runtime names differ, retain the original material treatment and investigate rather than broadening the match.

No native captures have been generated for this candidate. No whole-scene recolor or bloom change is included.
