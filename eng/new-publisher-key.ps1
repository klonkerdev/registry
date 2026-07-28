[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9][a-z0-9-]*$')]
    [string] $KeyId,

    [Parameter(Mandatory)]
    [string] $PrivateKeyPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = [System.IO.Path]::GetFullPath(
    (Join-Path -Path $PSScriptRoot -ChildPath '..'))
$privatePath = [System.IO.Path]::GetFullPath($PrivateKeyPath)
$publicDirectory = Join-Path -Path $repositoryRoot -ChildPath 'keys'
$publicPath = Join-Path -Path $publicDirectory -ChildPath "$KeyId.spki"
if (
    (Test-Path -LiteralPath $privatePath) -or
    (Test-Path -LiteralPath $publicPath)
) {
    throw 'Refusing to overwrite an existing publisher key.'
}

$privateParent = [System.IO.Directory]::GetParent($privatePath)
if ($null -eq $privateParent) {
    throw "Private key path '$privatePath' has no parent directory."
}

[System.IO.Directory]::CreateDirectory($privateParent.FullName) | Out-Null
[System.IO.Directory]::CreateDirectory($publicDirectory) | Out-Null
$utf8 = [System.Text.UTF8Encoding]::new($false)
$rsa = [System.Security.Cryptography.RSA]::Create(3072)
try {
    [System.IO.File]::WriteAllText(
        $privatePath,
        "$($rsa.ExportPkcs8PrivateKeyPem())`n",
        $utf8)
    [System.IO.File]::WriteAllText(
        $publicPath,
        "$([System.Convert]::ToBase64String(
            $rsa.ExportSubjectPublicKeyInfo()))`n",
        $utf8)
}
finally {
    $rsa.Dispose()
}

Write-Host "Created public publisher key '$publicPath'."
Write-Host (
    "Private key '$privatePath' is not tracked. Back it up securely and " +
    'configure KLONKER_REGISTRY_SIGNING_KEY for authorized builds.')
