# Memory reveal clock

The countdown reuses the acquired, integrated static `portal_glow.png` by
Bobardo from Modern 2D Animated Chests FREE Demo 1.0.2 (Unity Asset Store Standard
EULA, source mapping in `assets/chests/SOURCE.txt`), and the four-point
`milestone/sparkle.png` by Kenneth Foldal Moe / Archanor VFX from Toon FX 1.52
(same recorded EULA; source paths and hashes in [Jelly fragments](jelly-fragments.md)).
Both runtime textures were inspected before reuse; no new asset was acquired.
They have no imported animation. Number spring, travelling glint, endpoint light,
and final-three-second amber pulse are game-authored and follow the actual reveal
clock. The progress track is an interface primitive. Reduced motion retains the
number, real remaining fill and static glint without scaling, travel or pulsing.
