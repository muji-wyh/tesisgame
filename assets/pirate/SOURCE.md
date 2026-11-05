# Pirate / Captain Clover

This is an optimized derivative of the custom character authored with Blender CLI
at the user's request. The user supplied the pirate-slime reference image; its
original creator and license were not provided. No third-party license or ownership
of that reference is claimed.

The full editable source, original image and original high-resolution GLB remain
in `Q:/uwok/boss`. The image is a design reference, not a downloaded game model.
The character geometry, recessed mouth, vertex colors and twenty-two animation clips
were authored locally with Blender 5.2.2 LTS. The game derivative was generated
from that model, not from the acquired Frog used by Bramble.

The derivative uses two motion groups: an elastic body with shared `Bite_Open`,
`Eye_Squint`, `Smile_Smirk` and `Tongue_Out` morphs, and a rigid hat.
`Q:/uwok/boss/taunt_library.py` supplies the ten locally authored taunt timelines
and the additional eye, smile and tongue deformations. The original twelve
actions retain their names and timings. `taunt-designs.json` records each new
gesture's design and inspection time; all four weights reset to zero per clip.
Five finish materials preserve the original colors through
vertex colors. The opened lining is refitted to the reduced body with clearance
to prevent triangulation intersections. There are no texture downloads, skeleton, external buffer files,
compressed geometry extensions or runtime Blender dependencies.

`manifest.json` records source hashes, measured output budgets and animation names.
`optimization-report.json` records the final glTF geometry and animation audit.
The approved transparent portrait was rendered from the actual optimized model
in Godot's GL Compatibility renderer and is retained while extending the action
pack. The manifest records its source model and the new Idle verification
separately when their output hashes differ. It is an integrated derivative
preview, not source listing artwork.
