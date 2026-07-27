# Contributing

Contributions should keep the official catalog small, understandable, safe,
and useful to beginner developers.

## Template acceptance

A template should:

- generate a complete, focused starter project;
- have a clear family and independently versioned variant;
- avoid unnecessary dependencies and downloads;
- use deterministic declared parameters only;
- include an accurate source-license declaration;
- contain no generator hooks, command execution, or installers;
- generate into a new or empty directory without merging or patching;
- include a concise generated README that explains the project;
- remain understandable without Klonker after generation.

Template content may describe commands that the user can run later. Klonker
itself must never execute those commands.

## Package conventions

Place source in:

```text
templates/<namespace>/<package>/
  package.toml
  content/                       optional shared payload
  variants/<variant>/
    variant.toml
    content/                     variant-specific payload
```

Namespace, package, and variant IDs must match their folder names. The
publisher derives `<namespace>.<package>.<variant>` and generates the runtime
`template.toml`, index entry, checksum, size, and ZIP path. Do not add a
handwritten catalog entry.

Use the `std` namespace for Klonker's standard beginner-focused templates.
Other namespaces such as `community` or `android` can group separately
reviewed collections later. A namespace is part of template identity; it does
not grant trust by itself.

Put parameters, language, common tags, licensing, presentation metadata, and
shared files at package scope. Put version, target OS, build system,
purpose-specific tags, prerequisites, and target-specific files at variant
scope. Use the explicit build-system ID `none` when the concept does not
apply. Use `.sbn` only for UTF-8 text that needs rendering. Store other assets
as ordinary files so they are copied byte-for-byte.

Source-code templates may generate scripts used by their target platform, but
Klonker must treat them only as payload bytes. Never add a package mechanism
that asks Klonker to execute a generated script, installer, build tool, or
setup command.

All paths must be portable safe relative paths. Do not use:

- absolute, UNC, rooted, or drive-qualified paths;
- `.` or `..` segments;
- Windows reserved device names;
- case-only duplicate destinations;
- symbolic links or reparse points;
- one file path as another file's directory.

Published template IDs are stable. Bump `version` in `variant.toml` whenever
its published package bytes change. A shared package change affects every
variant, so every affected variant version must be bumped. Do not replace
package content in place under an existing version.

## Pull request workflow

Run:

```powershell
.\eng\build.ps1
.\eng\validate.ps1
```

Then review the generated `dist/registry.json` diff and confirm that only the
expected package ZIP artifacts were added or changed.

Pull requests should explain:

- what the template generates;
- its intended beginner use case;
- its toolchain prerequisites;
- source and dependency licenses;
- which generated files or parameters changed.

Keep unrelated templates out of the same pull request.
