[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = [System.IO.Path]::GetFullPath(
    (Join-Path -Path $PSScriptRoot -ChildPath '..'))
$distRoot = [System.IO.Path]::GetFullPath(
    (Join-Path -Path $repositoryRoot -ChildPath 'dist'))
$runId = [Guid]::NewGuid().ToString('N')
$firstBuild = [System.IO.Path]::GetFullPath(
    (Join-Path -Path $repositoryRoot -ChildPath ".registry-validate-$runId-a"))
$secondBuild = [System.IO.Path]::GetFullPath(
    (Join-Path -Path $repositoryRoot -ChildPath ".registry-validate-$runId-b"))

Add-Type -AssemblyName System.IO.Compression

function Assert-RepositoryChild {
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $resolved = [System.IO.Path]::GetFullPath($Path)
    $relative = [System.IO.Path]::GetRelativePath($repositoryRoot, $resolved)
    if (
        [System.IO.Path]::IsPathRooted($relative) -or
        $relative -eq '.' -or
        $relative -eq '..' -or
        $relative.StartsWith(
            "..$([System.IO.Path]::DirectorySeparatorChar)",
            [System.StringComparison]::Ordinal) -or
        $relative.StartsWith(
            "..$([System.IO.Path]::AltDirectorySeparatorChar)",
            [System.StringComparison]::Ordinal)
    ) {
        throw "Path '$resolved' is outside the repository."
    }

    return $resolved
}

function Remove-ValidationDirectory {
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $safePath = Assert-RepositoryChild -Path $Path
    if (Test-Path -LiteralPath $safePath -PathType Container) {
        Remove-Item -LiteralPath $safePath -Recurse -Force
    }
}

function Get-RelativeFileNames {
    param(
        [Parameter(Mandatory)]
        [string] $Root
    )

    @(
        Get-ChildItem -LiteralPath $Root -File -Recurse |
            ForEach-Object {
                [System.IO.Path]::GetRelativePath($Root, $_.FullName).
                    Replace('\', '/')
            } |
            Sort-Object
    )
}

function Assert-DirectoriesEqual {
    param(
        [Parameter(Mandatory)]
        [string] $ExpectedRoot,

        [Parameter(Mandatory)]
        [string] $ActualRoot,

        [Parameter(Mandatory)]
        [string] $Description
    )

    if (-not (Test-Path -LiteralPath $ExpectedRoot -PathType Container)) {
        throw "$Description is missing expected directory '$ExpectedRoot'."
    }

    if (-not (Test-Path -LiteralPath $ActualRoot -PathType Container)) {
        throw "$Description is missing actual directory '$ActualRoot'."
    }

    $expectedNames = @(Get-RelativeFileNames -Root $ExpectedRoot)
    $actualNames = @(Get-RelativeFileNames -Root $ActualRoot)
    if ($expectedNames.Count -ne $actualNames.Count) {
        throw "$Description has a different file count."
    }

    for ($index = 0; $index -lt $expectedNames.Count; $index++) {
        if ($expectedNames[$index] -cne $actualNames[$index]) {
            throw "$Description differs at '$($expectedNames[$index])' and '$($actualNames[$index])'."
        }

        $expectedPath = Join-Path -Path $ExpectedRoot -ChildPath (
            $expectedNames[$index].Replace('/', [System.IO.Path]::DirectorySeparatorChar))
        $actualPath = Join-Path -Path $ActualRoot -ChildPath (
            $actualNames[$index].Replace('/', [System.IO.Path]::DirectorySeparatorChar))
        $expectedHash = (Get-FileHash -LiteralPath $expectedPath -Algorithm SHA256).Hash
        $actualHash = (Get-FileHash -LiteralPath $actualPath -Algorithm SHA256).Hash
        if ($expectedHash -cne $actualHash) {
            throw "$Description differs in file '$($expectedNames[$index])'."
        }
    }
}

function Assert-SafeRelativePath {
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string] $Context
    )

    if (
        [string]::IsNullOrWhiteSpace($Path) -or
        $Path.IndexOf([char] 0) -ge 0 -or
        $Path.Contains('\') -or
        $Path.StartsWith('/', [System.StringComparison]::Ordinal) -or
        $Path -match '^[A-Za-z]:' -or
        [System.IO.Path]::IsPathRooted($Path)
    ) {
        throw "$Context contains unsafe path '$Path'."
    }

    $segments = @($Path.Split('/'))
    foreach ($segment in $segments) {
        if (
            [string]::IsNullOrWhiteSpace($segment) -or
            $segment -eq '.' -or
            $segment -eq '..' -or
            $segment.IndexOfAny([char[]] '<>:"|?*') -ge 0 -or
            $segment.TrimEnd([char[]] @(' ', '.')) -cne $segment
        ) {
            throw "$Context contains unsafe path segment '$segment'."
        }

        $deviceName = $segment.Split('.')[0]
        if ($deviceName -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$') {
            throw "$Context contains reserved Windows device name '$segment'."
        }
    }
}

function Assert-PackageArchive {
    param(
        [Parameter(Mandatory)]
        [string] $ArchivePath,

        [Parameter(Mandatory)]
        [string] $TemplateId,

        [Parameter(Mandatory)]
        [string] $FamilyId,

        [Parameter(Mandatory)]
        [string] $VariantId,

        [Parameter(Mandatory)]
        [string] $Version,

        [Parameter(Mandatory)]
        [string] $Language
    )

    $stream = [System.IO.File]::OpenRead($ArchivePath)
    try {
        $archive = [System.IO.Compression.ZipArchive]::new(
            $stream,
            [System.IO.Compression.ZipArchiveMode]::Read,
            $false)
        try {
            $paths = [System.Collections.Generic.HashSet[string]]::new(
                [System.StringComparer]::OrdinalIgnoreCase)
            $hasManifest = $false
            $hasContent = $false
            $manifestText = $null
            foreach ($entry in $archive.Entries) {
                $path = $entry.FullName
                Assert-SafeRelativePath `
                    -Path $path `
                    -Context "Package '$TemplateId'"

                if (-not $paths.Add($path)) {
                    throw "Package '$TemplateId' contains case-colliding path '$path'."
                }

                $unixType = ($entry.ExternalAttributes -shr 16) -band 0xF000
                $windowsReparse = $entry.ExternalAttributes -band
                    [int] [System.IO.FileAttributes]::ReparsePoint
                if ($unixType -eq 0xA000 -or $windowsReparse -ne 0) {
                    throw "Package '$TemplateId' contains link entry '$path'."
                }

                if ($path -ceq 'template.toml') {
                    $hasManifest = $true
                    $reader = [System.IO.StreamReader]::new(
                        $entry.Open(),
                        [System.Text.UTF8Encoding]::new($false, $true),
                        $false)
                    try {
                        $manifestText = $reader.ReadToEnd()
                    }
                    finally {
                        $reader.Dispose()
                    }
                }

                if ($path.StartsWith('content/', [System.StringComparison]::Ordinal)) {
                    $hasContent = $true
                }
            }

            foreach ($path in $paths) {
                $segments = @($path.Split('/'))
                for ($count = 1; $count -lt $segments.Count; $count++) {
                    $ancestor = [string]::Join('/', $segments[0..($count - 1)])
                    if ($paths.Contains($ancestor)) {
                        throw "Package '$TemplateId' contains file/directory collision '$ancestor'."
                    }
                }
            }

            if (-not $hasManifest -or -not $hasContent) {
                throw "Package '$TemplateId' must contain template.toml and content files."
            }

            if (
                $null -eq $manifestText -or
                $manifestText -notmatch
                    '(?m)^\s*schema_version\s*=\s*0\s*(?:#.*)?$'
            ) {
                throw "Package '$TemplateId' must contain a schema-version-zero manifest."
            }

            $expectedManifestValues = [ordered] @{
                id = $TemplateId
                family_id = $FamilyId
                variant_id = $VariantId
                version = $Version
                language = $Language
            }
            foreach ($expected in $expectedManifestValues.GetEnumerator()) {
                $actual = Get-TopLevelTomlString `
                    -Toml $manifestText `
                    -Property $expected.Key `
                    -ManifestPath "$ArchivePath!/template.toml"
                if ($actual -cne $expected.Value) {
                    throw "Package '$TemplateId' manifest property '$($expected.Key)' does not match the index."
                }
            }
        }
        finally {
            $archive.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Get-TopLevelTomlString {
    param(
        [Parameter(Mandatory)]
        [string] $Toml,

        [Parameter(Mandatory)]
        [string] $Property,

        [Parameter(Mandatory)]
        [string] $ManifestPath
    )

    $firstTable = $Toml.IndexOf('[[', [System.StringComparison]::Ordinal)
    $topLevel = if ($firstTable -ge 0) {
        $Toml.Substring(0, $firstTable)
    }
    else {
        $Toml
    }
    $pattern = '(?m)^\s*{0}\s*=\s*"([^"]+)"\s*(?:#.*)?$' -f
        [System.Text.RegularExpressions.Regex]::Escape($Property)
    $matches = [System.Text.RegularExpressions.Regex]::Matches(
        $topLevel,
        $pattern)
    if ($matches.Count -ne 1) {
        throw "Manifest '$ManifestPath' must declare one top-level '$Property' string."
    }

    return $matches[0].Groups[1].Value
}

function Assert-SourceDefinition {
    $definitionPath = Join-Path -Path $repositoryRoot -ChildPath 'registry.toml'
    $definition = Get-Content -LiteralPath $definitionPath -Raw
    if (
        $definition -notmatch
            '(?m)^\s*schema_version\s*=\s*0\s*(?:#.*)?$'
    ) {
        throw 'Source registry.toml schema_version must be 0.'
    }

    $registryId = Get-TopLevelTomlString `
        -Toml $definition `
        -Property 'registry_id' `
        -ManifestPath $definitionPath
    if ($registryId -cne 'klonker.official') {
        throw "Source registry_id must be 'klonker.official'."
    }

    $templatesRoot = Join-Path -Path $repositoryRoot -ChildPath 'templates'
    $packageManifests = @(
        Get-ChildItem -LiteralPath $templatesRoot -Filter 'package.toml' -File -Recurse |
            Sort-Object FullName)
    if ($packageManifests.Count -eq 0) {
        throw 'Source registry must contain at least one discovered package.toml.'
    }

    $discoveredTemplates = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)
    $expectedTemplates = [System.Collections.Generic.List[object]]::new()
    foreach ($packageManifest in $packageManifests) {
        $relativePackagePath = [System.IO.Path]::GetRelativePath(
            $templatesRoot,
            $packageManifest.FullName).Replace('\', '/')
        $segments = @($relativePackagePath.Split('/'))
        if (
            $segments.Count -ne 3 -or
            $segments[2] -cne 'package.toml'
        ) {
            throw "Package '$relativePackagePath' must use <namespace>/<package>/package.toml."
        }

        $packageToml = Get-Content -LiteralPath $packageManifest.FullName -Raw
        $namespace = Get-TopLevelTomlString `
            -Toml $packageToml `
            -Property 'namespace' `
            -ManifestPath $packageManifest.FullName
        $packageId = Get-TopLevelTomlString `
            -Toml $packageToml `
            -Property 'id' `
            -ManifestPath $packageManifest.FullName
        if (
            $namespace -cne $segments[0] -or
            $packageId -cne $segments[1]
        ) {
            throw "Package '$relativePackagePath' identity must match its folders."
        }

        $name = Get-TopLevelTomlString `
            -Toml $packageToml `
            -Property 'name' `
            -ManifestPath $packageManifest.FullName
        $licenseSummary = Get-TopLevelTomlString `
            -Toml $packageToml `
            -Property 'license_summary' `
            -ManifestPath $packageManifest.FullName
        $language = Get-TopLevelTomlString `
            -Toml $packageToml `
            -Property 'language' `
            -ManifestPath $packageManifest.FullName
        $variantsRoot = Join-Path -Path $packageManifest.DirectoryName -ChildPath (
            'variants')
        $variantDirectories = @(
            Get-ChildItem -LiteralPath $variantsRoot -Directory |
                Sort-Object Name)
        if ($variantDirectories.Count -eq 0) {
            throw "Package '$namespace.$packageId' must contain variants."
        }

        foreach ($variantDirectory in $variantDirectories) {
            $variantManifest = Join-Path -Path $variantDirectory.FullName -ChildPath (
                'variant.toml')
            if (-not (Test-Path -LiteralPath $variantManifest -PathType Leaf)) {
                throw "Variant '$($variantDirectory.FullName)' is missing variant.toml."
            }

            $variantToml = Get-Content -LiteralPath $variantManifest -Raw
            $variantId = Get-TopLevelTomlString `
                -Toml $variantToml `
                -Property 'id' `
                -ManifestPath $variantManifest
            if ($variantId -cne $variantDirectory.Name) {
                throw "Variant '$variantManifest' ID must match its folder."
            }

            $templateId = "$namespace.$packageId.$variantId"
            if (-not $discoveredTemplates.Add($templateId)) {
                throw "Source registry contains duplicate template '$templateId'."
            }

            $expectedTemplates.Add([pscustomobject] @{
                FamilyId = "$namespace.$packageId"
                VariantId = $variantId
                TemplateId = $templateId
                Name = $name
                Description = Get-TopLevelTomlString `
                    -Toml $variantToml `
                    -Property 'description' `
                    -ManifestPath $variantManifest
                Version = Get-TopLevelTomlString `
                    -Toml $variantToml `
                    -Property 'version' `
                    -ManifestPath $variantManifest
                TargetOs = Get-TopLevelTomlString `
                    -Toml $variantToml `
                    -Property 'target_os' `
                    -ManifestPath $variantManifest
                BuildSystem = Get-TopLevelTomlString `
                    -Toml $variantToml `
                    -Property 'build_system' `
                    -ManifestPath $variantManifest
                Language = $language
                LicenseSummary = $licenseSummary
            })
        }
    }

    return @($expectedTemplates | Sort-Object TemplateId)
}

function Assert-Registry {
    param(
        [Parameter(Mandatory)]
        [string] $RegistryRoot,

        [Parameter(Mandatory)]
        [object[]] $ExpectedTemplates
    )

    $indexPath = Join-Path -Path $RegistryRoot -ChildPath 'registry.json'
    $registry = Get-Content -LiteralPath $indexPath -Raw | ConvertFrom-Json
    if ($registry.schema_version -ne 1) {
        throw 'Published registry schema_version must be 1.'
    }

    if ($registry.registry_id -cne 'klonker.official') {
        throw "Published registry_id must be 'klonker.official'."
    }

    $templates = @($registry.templates)
    if ($templates.Count -eq 0) {
        throw 'Published registry must contain at least one template.'
    }

    if ($templates.Count -ne $ExpectedTemplates.Count) {
        throw "Published registry template count does not match discovered source variants."
    }

    $publishedTemplateIds = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)
    foreach ($template in $templates) {
        $publishedTemplateIds.Add([string] $template.template_id) | Out-Null
    }

    foreach ($expectedTemplate in $ExpectedTemplates) {
        if (-not $publishedTemplateIds.Contains($expectedTemplate.TemplateId)) {
            throw "Discovered source template '$($expectedTemplate.TemplateId)' is absent from the published registry."
        }
    }

    $identities = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)
    $requiredProperties = @(
        'family_id',
        'variant_id',
        'template_id',
        'name',
        'description',
        'version',
        'target_os',
        'build_system',
        'language',
        'package_path',
        'license_summary',
        'package_sha256',
        'package_size_bytes'
    )
    foreach ($template in $templates) {
        $expectedTemplate = $ExpectedTemplates |
            Where-Object {
                $_.TemplateId -ceq [string] $template.template_id
            } |
            Select-Object -First 1
        if ($null -eq $expectedTemplate) {
            throw "Published template '$($template.template_id)' has no discovered source."
        }

        foreach ($property in $requiredProperties) {
            if (
                $template.PSObject.Properties.Name -notcontains $property -or
                [string]::IsNullOrWhiteSpace([string] $template.$property)
            ) {
                throw "Published template property '$property' is required."
            }
        }

        $identity = "$($template.template_id)@$($template.version)"
        if (-not $identities.Add($identity)) {
            throw "Published registry contains duplicate identity '$identity'."
        }

        $expectedTemplateId =
            "$($template.family_id).$($template.variant_id)"
        if ($template.template_id -cne $expectedTemplateId) {
            throw "Published template '$identity' does not follow family.variant identity."
        }

        $sourceMappings = [ordered] @{
            family_id = 'FamilyId'
            variant_id = 'VariantId'
            name = 'Name'
            description = 'Description'
            version = 'Version'
            target_os = 'TargetOs'
            build_system = 'BuildSystem'
            language = 'Language'
            license_summary = 'LicenseSummary'
        }
        foreach ($mapping in $sourceMappings.GetEnumerator()) {
            if (
                [string] $template.($mapping.Key) -cne
                    [string] $expectedTemplate.($mapping.Value)
            ) {
                throw "Published template '$identity' property '$($mapping.Key)' does not match its TOML source."
            }
        }

        Assert-SafeRelativePath `
            -Path ([string] $template.package_path) `
            -Context "Registry template '$identity'"
        if (
            -not ([string] $template.package_path).StartsWith(
                'packages/',
                [System.StringComparison]::Ordinal)
        ) {
            throw "Registry package '$identity' must be beneath packages/."
        }

        $packagePath = [System.IO.Path]::GetFullPath(
            (Join-Path -Path $RegistryRoot -ChildPath (
                ([string] $template.package_path).Replace(
                    '/',
                    [System.IO.Path]::DirectorySeparatorChar))))
        $relative = [System.IO.Path]::GetRelativePath($RegistryRoot, $packagePath)
        if (
            [System.IO.Path]::IsPathRooted($relative) -or
            $relative -eq '..' -or
            $relative.StartsWith(
                "..$([System.IO.Path]::DirectorySeparatorChar)",
                [System.StringComparison]::Ordinal)
        ) {
            throw "Registry package '$identity' resolves outside the distribution."
        }

        if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) {
            throw "Registry package '$identity' is missing '$packagePath'."
        }

        $package = Get-Item -LiteralPath $packagePath
        if ($package.Length -ne [int64] $template.package_size_bytes) {
            throw "Registry package '$identity' has an incorrect size."
        }

        $actualHash = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).
            Hash.ToLowerInvariant()
        if ($actualHash -cne [string] $template.package_sha256) {
            throw "Registry package '$identity' has an incorrect SHA-256."
        }

        Assert-PackageArchive `
            -ArchivePath $packagePath `
            -TemplateId ([string] $template.template_id) `
            -FamilyId ([string] $template.family_id) `
            -VariantId ([string] $template.variant_id) `
            -Version ([string] $template.version) `
            -Language ([string] $template.language)
    }
}

try {
    if (-not (Test-Path -LiteralPath $distRoot -PathType Container)) {
        throw "Committed distribution '$distRoot' is missing. Run eng/build.ps1."
    }

    $expectedTemplates = @(Assert-SourceDefinition)
    $packScript = Join-Path -Path $PSScriptRoot -ChildPath 'pack-registry.ps1'
    & $packScript -SourceRoot $repositoryRoot -OutputRoot $firstBuild
    & $packScript -SourceRoot $repositoryRoot -OutputRoot $secondBuild

    Assert-DirectoriesEqual `
        -ExpectedRoot $firstBuild `
        -ActualRoot $secondBuild `
        -Description 'Repeated registry builds'
    Assert-DirectoriesEqual `
        -ExpectedRoot $firstBuild `
        -ActualRoot $distRoot `
        -Description 'Committed distribution'
    Assert-Registry `
        -RegistryRoot $distRoot `
        -ExpectedTemplates $expectedTemplates

    Write-Host 'Klonker registry validation succeeded.'
}
finally {
    Remove-ValidationDirectory -Path $firstBuild
    Remove-ValidationDirectory -Path $secondBuild
}
