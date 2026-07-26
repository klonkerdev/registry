# Registry source layout version 0

The source tree is human-authored TOML plus payload files. `dist/` is generated
and must never be edited by hand.

## Registry metadata

`registry.toml` describes the catalog authority:

```toml
schema_version = 0
registry_id = "klonker.official"
display_name = "Klonker official templates"
```

It deliberately contains no template array.

## Discovery and identity

The publisher discovers:

```text
templates/<namespace>/<package>/package.toml
templates/<namespace>/<package>/variants/<variant>/variant.toml
```

Folder names and declared IDs must match. Identity is derived as:

| Source | Derived value |
| --- | --- |
| `std/cpp-cli` | family ID `std.cpp-cli` |
| `std/cpp-cli/variants/linux-cmake` | variant ID `linux-cmake` |
| combined | template ID `std.cpp-cli.linux-cmake` |

Namespace, package, and variant segments begin with a lowercase letter and
contain only lowercase letters, numbers, and hyphens.

## Package metadata

`package.toml` owns values shared by every variant:

```toml
schema_version = 0
namespace = "std"
id = "cpp-cli"

name = "C++ CLI"
description = "A small dependency-free C++ command-line starter."

source_license = "MIT"
license_summary = "Generated source: MIT"
logo = "template-logo.png"
tags = ["cli", "native", "starter", "cpp"]

[[parameters]]
id = "project_name"
type = "string"
label = "Project name"
required = true
default = "MyCliApp"
validation = "cpp_identifier"
```

Version zero permits `[[parameters]]` tables at package scope. The logo is
optional; all other shown top-level properties are required.

## Variant metadata

Each `variant.toml` owns independently versioned target details:

```toml
schema_version = 0
id = "linux-cmake"
description = "A small Linux C++ command-line application using CMake."
version = "0.1.0"
target_os = "linux"
build_system = "cmake"
favorite = false

[[prerequisites]]
id = "cmake"
name = "CMake 3.20 or later"
description = "Required after generation to configure and build the project."
required_for = "build"
```

Version zero permits `[[prerequisites]]` and variant-specific
`[[parameters]]` tables. Duplicate parameter IDs are rejected when Klonker
loads the generated runtime manifest.

## Payload composition

Package files outside `variants/` and `package.toml` are shared. Files beneath
one variant, excluding `variant.toml`, are specific to that variant. Their
relative paths are merged into one archive:

```text
package content/src/main.cpp.sbn
variant content/CMakeLists.txt.sbn
                 |
                 v
archive content/src/main.cpp.sbn
archive content/CMakeLists.txt.sbn
```

The publisher adds a generated `template.toml` at the archive root. It rejects
unsafe paths, links/reparse points, case-insensitive duplicates, and
file/directory collisions. Variant files cannot override shared files.

## Publication

`eng/build.ps1` discovers every package and variant, composes runtime
manifests, creates sorted fixed-timestamp ZIPs, calculates SHA-256 and size,
and emits `dist/registry.json`. `eng/validate.ps1` rebuilds twice and requires
both builds and committed `dist/` to be byte-for-byte identical.
