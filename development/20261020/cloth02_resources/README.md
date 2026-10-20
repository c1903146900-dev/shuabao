# Exact cloth02 baked-resource archive

This preserves the nine actual Godot 4.6.3 exported binary meshes, not regenerated approximations. Fifteen text chunks contain zlib-compressed Base64 data. No chunk exceeds 48 KiB. MANIFEST.json pins every chunk and decoded resource; BAKE_MANIFEST.json is the unchanged original export manifest. DEPENDENCIES.json records the exact source inputs and external resource references.

Restore with Python standard library only:
python restore.py --output NEW_EMPTY_DESTINATION

The destination must not exist. Exactly mesh_00.res through mesh_08.res are permitted. The script validates all data before creating the destination, caps total decoded data at 2 MiB, rejects duplicate or unexpected chunk paths and verifies every decoded SHA-256. It never executes Godot or authoring code.

The authoring directory preserves the three exact source files used for export. The export script contains its original fixed local output directory; it is provenance, not a portable rerun command. Use restore.py to recover the exact binaries and avoid resource UID variation from another export. The original imported model/textures and exact palette shader remain required at their res:// paths. This package alone is not a complete game.

Export completed, but fresh-process dependency validation and visual acceptance are separate pending checks. These resources are not installed into the production game. No gameplay, skeleton, animation or collision acceptance is implied.
