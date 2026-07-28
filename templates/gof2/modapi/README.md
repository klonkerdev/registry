# GOF2 ModAPI templates

The `gof2.modapi` package provides small Lua starters for Galaxy on Fire 2
Full HD on Windows using
[`KaamoClubModApi`](https://github.com/1337Skid/KaamoClubModApi).

## Source and license

The package was derived from the upstream GPL-3.0-only loader, Lua bindings,
and example mods. Generated projects therefore declare GPL-3.0-only and
include the full license text. The templates do not redistribute the example
`.aei` files: the upstream asset notice attributes those files to Fishlabs.
The custom-content variant creates an asset-guidance directory instead.

API names and lifecycle assumptions were checked against the source bindings
and examples:

- the loader enumerates direct child folders beneath `mods/` and executes
  `<folder>/init.lua`;
- the entry-point directory is added to Lua's module path, permitting local
  modules such as `require("state")`;
- `RegisterEvent`, `HookFunction`, `RegisterWindow`, and `wait` are global
  bindings;
- systems, stations, and missions must be created during `EarlyInit`;
- ImGui windows use `RegisterWindow`;
- wrapping render hooks preserve the original function with `ctx:call()`.

## Editor support

Every generated variant contains:

```text
.vscode/extensions.json
.vscode/settings.json
.luarc.json
.lua-definitions/kaamoclub_modapi.d.lua
MODAPI-DEVELOPMENT.md
```

Visual Studio Code recommends the Lua extension by LuaLS and loads the local
definition library with Lua 5.4 semantics. The portable `.luarc.json` provides
the same project model to other LuaLS clients. Definitions cover all globals,
properties, and methods registered by `LuaManager::bind_api()`, all event
names triggered by `EventManager`, every hook name triggered by `hooks.cpp`,
typed hook contexts, and the table fields consumed by item, ship, agent,
dialogue, cutscene, route, and portrait APIs.

The definition file is inert editor metadata and must not be loaded with
`require`. It provides no runtime implementation, game binary, ModAPI,
debugger, or third-party assets.

Users should still confirm behavior against the exact ModAPI release they
install because the external API can evolve independently from this registry.

## Variants

| Variant | Purpose | Generated structure |
| --- | --- | --- |
| `event-starter` | one-time startup plus gameplay events | `init.lua`, README, license |
| `imgui-menu` | configurable in-game utility window | `init.lua`, README, license |
| `render-hook` | main-menu and in-game 2D text hooks | `init.lua`, README, license |
| `campaign-mission` | custom system/station/mission and dialogue | `init.lua`, `state.lua`, README, license |
| `custom-content` | systems, stations, item/blueprint, asset guidance | `init.lua`, `assets/README.md`, README, license |
| `all-in-one` | modular composition of all five focused examples | entry point, six Lua modules, asset guidance, README, license |

The all-in-one variant is a cohesive example rather than a concatenation of
the focused starters. Its entry point loads separate content, event, mission,
menu, and rendering modules that coordinate through a shared state module.
This also demonstrates the loader's local-module support while keeping each
ModAPI concern independently editable.

All variants target Windows, declare `language = "lua"`, and use
`build_system = "none"`. Their generated project root is the mod folder
itself. Install it manually as:

```text
<Galaxy on Fire 2>/mods/<mod-id>/init.lua
```

Klonker does not install the ModAPI, copy files into the game, launch the game,
or execute the generated Lua. After generation the mod belongs entirely to
the user.
