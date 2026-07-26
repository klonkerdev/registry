# Klonker registry contributor guidance

This repository publishes the official template catalog consumed by Klonker.
It contains reviewed template sources and deterministic machine-generated
distribution artifacts. It does not contain the Klonker desktop application.

## Repository layout

- `registry.toml` contains registry-level authority metadata only.
- `templates/<namespace>/<package>/package.toml` contains shared metadata,
  parameters, assets, and optional shared content.
- `variants/<variant>/variant.toml` contains independently versioned target
  and build-system metadata plus prerequisites.
- `dist/registry.json` and `dist/packages/` are generated publication files.
- `eng/build.ps1` discovers all package and variant folders and regenerates
  `dist/`; never maintain a parallel handwritten template list.
- `eng/validate.ps1` validates source, deterministic output, checksums, paths,
  and committed distribution artifacts.

## Required workflow

Inspect the relevant manifest, content, and generated index before changing
behavior. After changing a template or catalog entry:

```powershell
.\eng\build.ps1
.\eng\validate.ps1
```

Commit both the reviewed source and the corresponding `dist/` changes. Never
edit generated files in `dist/` by hand.

## Security and quality rules

- Treat every template path and expression as untrusted input.
- Never add hooks, commands, executable setup scripts, or process execution.
- Templates must not access the filesystem, network, environment, clocks, or
  arbitrary .NET APIs while rendering.
- Use only relative package paths. Never add rooted, drive-qualified, UNC,
  traversal, symbolic-link, reparse-point, or case-colliding paths.
- Keep output deterministic. Do not include timestamps, random values, or
  machine-specific paths.
- Keep namespace, package, and variant IDs identical to their folder names.
- Declare the generated source license accurately in `package.toml`.
- Bump a template version whenever published package bytes change.
- Keep reusable files at package scope and target/build-specific files at
  variant scope. Shared and variant paths must never collide.
- Prefer small, reviewable changes and keep documentation aligned with actual
  behavior.
- Do not claim a template, platform, or feature is available until its source
  and generated artifact are present and validation passes.

Klonker generates files only. Templates must not attempt to build, run,
install, initialize Git, or manage a generated project afterward.
