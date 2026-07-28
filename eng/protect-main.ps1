[CmdletBinding()]
param(
    [string] $Repository = 'klonkerdev/registry'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Repository -cnotmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
    throw "Repository '$Repository' must use owner/name form."
}

if ($null -eq (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI (gh) is required to configure branch protection.'
}

& gh auth status
if ($LASTEXITCODE -ne 0) {
    throw 'GitHub CLI is not authenticated.'
}

$protection = @{
    required_status_checks = @{
        strict = $true
        contexts = @('validate')
    }
    enforce_admins = $true
    required_pull_request_reviews = @{
        dismissal_restrictions = @{}
        dismiss_stale_reviews = $true
        require_code_owner_reviews = $true
        required_approving_review_count = 1
        require_last_push_approval = $true
        bypass_pull_request_allowances = @{}
    }
    restrictions = $null
    required_linear_history = $true
    allow_force_pushes = $false
    allow_deletions = $false
    block_creations = $false
    required_conversation_resolution = $true
    lock_branch = $false
    allow_fork_syncing = $true
}
$temporaryPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath (
    "klonker-branch-protection-$([Guid]::NewGuid().ToString('N')).json")
try {
    $protection |
        ConvertTo-Json -Depth 8 |
        Set-Content -LiteralPath $temporaryPath -Encoding utf8NoBOM
    & gh api `
        --method PUT `
        -H 'Accept: application/vnd.github+json' `
        -H 'X-GitHub-Api-Version: 2022-11-28' `
        "repos/$Repository/branches/main/protection" `
        --input $temporaryPath
    if ($LASTEXITCODE -ne 0) {
        throw "GitHub rejected branch protection for '$Repository'."
    }
}
finally {
    if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
        Remove-Item -LiteralPath $temporaryPath -Force
    }
}

Write-Host "Protected '$Repository' main branch with validation and review."
