# Klonker official template registry

This is the source and publication repository for the official templates used
by Klonker, a Windows-first desktop project generator.

The public registry index is:

```text
https://raw.githubusercontent.com/klonkerdev/registry/main/dist/registry.json
```

Klonker downloads the index and package ZIPs, verifies the detached publisher
signature plus each declared size and SHA-256, and caches validated artifacts
for offline use. Publisher trust is pinned in the app rather than accepted
from registry-controlled metadata.

## Available templates

The publisher generates the complete
[Markdown catalog](dist/catalog.md) and matching
[machine-readable catalog](dist/catalog.json) from discovered package and
variant manifests. Adding a package or variant never requires editing this
README or a handwritten test list. Package-specific long-form documentation
lives beside its `package.toml` and is linked by the generated catalog.

## Repository layout

```text
registry.toml                        Registry authority metadata only
templates/<namespace>/<package>/     Shared package metadata and content
  package.toml
  variants/<variant>/
    variant.toml
    content/
dist/registry.json                   Published machine-generated index
dist/registry.json.sig.json          Detached publisher signature
dist/catalog.md                      Generated repository catalog
dist/catalog.json                    Generated static-site catalog data
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
  "enabled": true,
  "require_signature": true,
  "publisher_id": "klonker.official",
  "trusted_keys": [
    {
      "key_id": "2026-primary",
      "algorithm": "rsa-pkcs1-sha256",
      "public_key_spki": "<pinned Base64 SPKI key>",
      "revoked": false
    }
  ]
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

The signing key is supplied through `-SigningKeyPath` or
`KLONKER_REGISTRY_SIGNING_KEY`; private keys are never committed. Rotation
adds a new pinned public key to Klonker before switching `signing_key_id`.
Compromised or retired keys remain in local trust metadata as revoked so old
signatures cannot become trusted again.

Security reports should follow [SECURITY.md](SECURITY.md). Repository tooling
and documentation are MIT-licensed; generated source licensing is declared
per template.
