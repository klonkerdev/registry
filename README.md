# Klonker official template registry

This is the source and publication repository for the official templates used
by Klonker, a Windows-first desktop project generator.

The public registry index is:

```text
https://raw.githubusercontent.com/klonkerdev/registry/main/dist/registry.json
```

Klonker downloads the index and package ZIPs, verifies their declared size and
SHA-256, and caches validated packages for offline use. SHA-256 detects
corruption or unexpected bytes; it is not a cryptographic publisher
signature.

## Available templates

| Template | Variant | Version | Generated source license |
| --- | --- | --- | --- |
| C++ CLI | Windows + CMake | 0.1.1 | MIT |
| C++ CLI | Windows + GNU Make | 0.1.1 | MIT |
| C++ CLI | Windows + xmake | 0.1.1 | MIT |
| C++ CLI | Linux + CMake | 0.1.1 | MIT |
| C++ CLI | Linux + GNU Make | 0.1.1 | MIT |
| C++ CLI | Linux + xmake | 0.1.1 | MIT |
| GOF2 ModAPI | Event starter | 0.1.0 | GPL-3.0-only |
| GOF2 ModAPI | ImGui menu | 0.1.0 | GPL-3.0-only |
| GOF2 ModAPI | Render hook | 0.1.0 | GPL-3.0-only |
| GOF2 ModAPI | Campaign mission | 0.1.0 | GPL-3.0-only |
| GOF2 ModAPI | Custom content | 0.1.0 | GPL-3.0-only |
| GOF2 ModAPI | All in one | 0.1.0 | GPL-3.0-only |

The C++ CLI family generates a small dependency-free command-line project with
a reusable argument parser. Windows and Linux variants are available for
modern target-based CMake, a transparent GNU Makefile, and a concise xmake
configuration.

The GOF2 ModAPI family generates direct `mods/<mod-id>/init.lua` projects for
the Windows PC game. Its six variants cover events, ImGui menus, 2D rendering
hooks, a small campaign mission, custom systems/items/assets, and a modular
all-in-one showcase combining those capabilities. They declare Lua as their
language and `none` as their build system. See
[GOF2 ModAPI templates](docs/gof2-modapi.md) for API provenance, structure,
licensing, and limitations.

## Repository layout

```text
registry.toml                        Registry authority metadata only
templates/<namespace>/<package>/     Shared package metadata and content
  package.toml
  variants/<variant>/
    variant.toml
    content/
dist/registry.json                   Published machine-generated index
dist/packages/                       Published deterministic package ZIPs
eng/build.ps1                        Rebuilds dist/
eng/validate.ps1                     Runs standalone repository validation
```

There is no handwritten template list. The publisher recursively discovers
`templates/*/*/package.toml` and each package's `variants/*/variant.toml`.
For example:

```text
templates/std/cpp-cli/variants/linux-cmake
```

derives family ID `std.cpp-cli` and template ID
`std.cpp-cli.linux-cmake`. Namespace folders keep large catalogs navigable and
leave room for `community`, `android`, or other reviewed collections without
flattening every variant into one directory.

Package-level content is merged with the selected variant's content. The
publisher generates the runtime `template.toml`; source authors maintain only
`package.toml` and `variant.toml`. Case-insensitive collisions between shared
and variant files are rejected.

Package metadata declares a language ID. Variant tags are merged with
package-wide tags into the runtime manifest, so purpose-specific terms such as
`imgui`, `campaign`, or `assets` remain independently filterable.

`dist/` is intentionally committed. Raw GitHub URLs serve those exact files,
and each index entry points to a package path relative to `dist/registry.json`.
The complete source contract is documented in
[docs/source-layout-v0.md](docs/source-layout-v0.md).

## Build and validate

PowerShell 7 is recommended. No administrator privileges, SDK, build tool, or
network access is required.

```powershell
.\eng\build.ps1
.\eng\validate.ps1
```

`build.ps1` creates deterministic ZIPs and regenerates the index. Validation
builds the registry twice, verifies byte-for-byte determinism, checks the
committed `dist/` tree, validates package checksums and sizes, and inspects ZIP
paths for unsafe or colliding entries.

## Add or update a template

1. Add or edit `templates/<namespace>/<package>/package.toml`.
2. Put reusable payload beneath the package's `content/`.
3. Add `variants/<variant>/variant.toml` and variant-specific `content/`.
4. If published bytes changed, assign a new variant version.
5. Run `.\eng\build.ps1`.
6. Run `.\eng\validate.ps1`.
7. Review and commit both source and generated `dist/` changes.

The C++ CLI source demonstrates the layout:

```text
templates/std/cpp-cli/
  package.toml
  template-logo.png
  content/src/
  variants/
    windows-cmake/
    windows-make/
    windows-xmake/
    linux-cmake/
    linux-make/
    linux-xmake/
templates/gof2/modapi/
  package.toml
  content/LICENSE.txt
  variants/
    event-starter/
    imgui-menu/
    render-hook/
    campaign-mission/
    custom-content/
    all-in-one/
```

Text files ending in `.sbn` are rendered by Klonker with its restricted
Scriban value model; other files are copied byte-for-byte. See
[CONTRIBUTING.md](CONTRIBUTING.md) for review requirements.

## Configure Klonker manually

Klonker seeds this endpoint for new installations. Existing installations can
add it to `%LOCALAPPDATA%\Klonker\registries.json`:

```json
{
  "name": "Klonker official templates",
  "kind": "remote",
  "location": "https://raw.githubusercontent.com/klonkerdev/registry/main/dist/registry.json",
  "enabled": true
}
```

## Security and lifecycle

Template packages are data, never trusted programs. Official manifests may
not define or invoke arbitrary commands, generator hooks, build tools,
installers, or network access. Source-code payloads such as Lua remain inert:
Klonker renders and writes them but never executes them. Paths are validated
again by Klonker before planning and generation.

Klonker never builds or manages generated projects. After generation, every
file belongs entirely to the user and is detached from Klonker.

Security reports should follow [SECURITY.md](SECURITY.md). Repository tooling
and documentation are MIT-licensed; generated source licensing is declared
per template.
