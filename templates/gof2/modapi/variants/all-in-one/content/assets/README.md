# Custom assets

Place ModAPI-compatible assets in this directory. The original ModAPI examples
include `.aei` files whose rights are attributed to Fishlabs; those files are
intentionally not redistributed by this template.

Keep runtime paths relative to the game directory:

```lua
asset:CreateTexture("mods/your_mod_id/assets/item-icon.aei")
```

Enable the commented texture and sprite integration in `content.lua` only
after adding an asset you have the right to distribute. Test asset IDs and
sprite indices against the exact ModAPI and game version you target.
