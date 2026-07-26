[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = [System.IO.Path]::GetFullPath(
    (Join-Path -Path $PSScriptRoot -ChildPath '..'))
$distRoot = [System.IO.Path]::GetFullPath(
    (Join-Path -Path $repositoryRoot -ChildPath 'dist'))
$stagingRoot = [System.IO.Path]::GetFullPath(
    (Join-Path -Path $repositoryRoot -ChildPath (
        ".registry-build-$([Guid]::NewGuid().ToString('N'))")))
$backupRoot = [System.IO.Path]::GetFullPath(
    (Join-Path -Path $repositoryRoot -ChildPath (
        ".dist-backup-$([Guid]::NewGuid().ToString('N'))")))

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
        throw "Refusing to modify path outside the repository: '$resolved'."
    }

    return $resolved
}

function Remove-RepositoryDirectory {
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $safePath = Assert-RepositoryChild -Path $Path
    if (Test-Path -LiteralPath $safePath -PathType Container) {
        Remove-Item -LiteralPath $safePath -Recurse -Force
    }
}

$published = $false
$backupCreated = $false
try {
    & (Join-Path -Path $PSScriptRoot -ChildPath 'pack-registry.ps1') `
        -SourceRoot $repositoryRoot `
        -OutputRoot $stagingRoot

    if (Test-Path -LiteralPath $distRoot) {
        Assert-RepositoryChild -Path $distRoot | Out-Null
        Move-Item -LiteralPath $distRoot -Destination $backupRoot
        $backupCreated = $true
    }

    try {
        Move-Item -LiteralPath $stagingRoot -Destination $distRoot
        $published = $true
    }
    catch {
        if (
            $backupCreated -and
            -not (Test-Path -LiteralPath $distRoot) -and
            (Test-Path -LiteralPath $backupRoot -PathType Container)
        ) {
            Move-Item -LiteralPath $backupRoot -Destination $distRoot
            $backupCreated = $false
        }

        throw
    }

    if ($backupCreated) {
        Remove-RepositoryDirectory -Path $backupRoot
        $backupCreated = $false
    }

    Write-Host "Klonker registry distribution rebuilt at '$distRoot'."
}
finally {
    Remove-RepositoryDirectory -Path $stagingRoot
    if ($published -and $backupCreated) {
        Remove-RepositoryDirectory -Path $backupRoot
    }
}
