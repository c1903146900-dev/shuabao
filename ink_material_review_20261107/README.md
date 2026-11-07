# Actual landed ink, not an empty warning ring

Isolated visual candidate on preserved motion_combo11. No gameplay-source or enemy behavior changes. Return-stroke candidate remains separate.

Normal r08a guard/support/pitcher observation guardteam01 reached the room, but ordinary skill use cleared it in about two seconds, so that run does not establish post-break cooperation. A second normal-route observation guardteam02 chose only ordinary attacks and dodge in the target room, without changing HP, AI, resources or skills. It recorded the real 2.1-second shield-break window, four landed zones, and two exposed applications over the bounded 22-second window. Existing complementary behavior is real; this sample did not prove a need for forced corridor blocking or redesign of support AI.

The clear visible issue was the landed damage material: inspected baseline frames16/32 showed a bright outline and extremely faint fill over dark tiles. It read as an empty warning ring despite being an already active physical corrosive disc.

The candidate increases the purple material fill and adds three quiet, fixed interior sheen marks while reducing the bright outline thickness. It uses the existing 48-point source-radius boundary approximation, without enlargement, new damage shapes, labels or prelanding prediction. Marks lie inside radius .657 even under conservative bounds. Source position/radius/time/identity validation, expiry, draw order and damage remain unchanged. It draws below actors and enemy warnings.

Actual candidate normal-route r04a observation passed. Six half-second samples followed one zone from left2.38 through .38 to removal; receipt errors empty. Viewed frame1 clearly reads as filled cartoon ink, and later samples preserve source expiry. This is not a matched-frame A/B, final aesthetic acceptance or a complete floor. More opaque ink may cover player ground effects more strongly; overlap still needs review.

Independent source review found only material-drawing changes plus regenerated seals; all243 manifest hashes verify. Candidate pack f400fce7fbfc1468c071d5896741345ad1ca6ffb30ccff19e597a41f29ea38e0. Build with python3 -I -B rebuild_20261106/build_ink_material.py NEW_DIRECTORY using original private recovery inputs. Public backup includes safe source/build/observers/aggregate summary, not private assets, screenshots, raw logs or conversation text.

Next: inspect concurrent player-ground effect overlap, normal UI and complete-floor regression before merging. Old combo11 remains accepted.
