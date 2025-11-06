#requires -Version 5.1
<#!
    Download all files from a GitHub repository and prepare Codex metadata.
    -----------------------------------------------------------------------
    This script connects to the GitHub REST API to enumerate every file in a
    repository tree, downloads each blob individually, and optionally emits a
    Codex-style manifest describing the retrieved files.  The manifest can be
    imported by downstream automation to keep Codex and GitHub in sync.

    Example
        .\Download-GitHubRepository.ps1 -Owner "owner" -Repository "project" `
            -Branch main -Destination "C:\\Temp\\project" -CodexManifestPath \
            "C:\\Temp\\project\\codex_manifest.json"
!#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $Owner,
    [Parameter(Mandatory)][string] $Repository,
    [string] $Branch = 'main',
    [string] $Destination = (Join-Path -Path $PWD -ChildPath 'github_repo'),
    [string] $Token,
    [string] $CodexManifestPath,
    [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-DestinationPath {
    param([string] $Path, [switch] $Force)

    if (Test-Path -LiteralPath $Path) {
        if (-not $Force) {
            throw "Destination '$Path' already exists. Use -Force to overwrite."
        }
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    return (Resolve-Path -LiteralPath $Path).Path
}

function New-GitHubHeaders {
    param([string] $Token)

    $headers = @{
        'User-Agent'      = 'Codex-GitHub-Downloader'
        'Accept'          = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
    }
    if (-not [string]::IsNullOrWhiteSpace($Token)) {
        $headers['Authorization'] = "Bearer $Token"
    }
    return $headers
}

function Invoke-GitHubRequest {
    param(
        [string] $Uri,
        [hashtable] $Headers
    )

    try {
        return Invoke-RestMethod -Uri $Uri -Headers $Headers -ErrorAction Stop
    }
    catch {
        throw "GitHub API request to '$Uri' failed: $($_.Exception.Message)"
    }
}

function Get-GitHubTree {
    param(
        [string] $Owner,
        [string] $Repository,
        [string] $Branch,
        [hashtable] $Headers
    )

    $refUri = "https://api.github.com/repos/$Owner/$Repository/git/trees/$Branch?recursive=1"
    $response = Invoke-GitHubRequest -Uri $refUri -Headers $Headers
    if (-not $response.tree) {
        throw "GitHub API did not return a repository tree for $Owner/$Repository@$Branch."
    }
    return $response.tree
}

function Save-GitHubBlob {
    param(
        [string] $Owner,
        [string] $Repository,
        [string] $Branch,
        [string] $Path,
        [hashtable] $Headers,
        [string] $DestinationRoot
    )

    $rawUri = "https://raw.githubusercontent.com/$Owner/$Repository/$Branch/$Path"
    $targetFile = Join-Path -Path $DestinationRoot -ChildPath $Path
    $targetDirectory = Split-Path -Path $targetFile -Parent
    if (-not (Test-Path -LiteralPath $targetDirectory)) {
        New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
    }

    try {
        Invoke-WebRequest -Uri $rawUri -Headers $Headers -OutFile $targetFile -UseBasicParsing -ErrorAction Stop
    }
    catch {
        throw "Failed to download '$Path' from GitHub: $($_.Exception.Message)"
    }
}

function Show-RepositoryTree {
    param([string] $Path)

    Write-Host "--- Repository contents ---" -ForegroundColor Cyan
    Get-ChildItem -LiteralPath $Path -Recurse | Sort-Object FullName | ForEach-Object {
        $relative = $_.FullName.Substring($Path.Length).TrimStart('\\','/')
        if ([string]::IsNullOrWhiteSpace($relative)) {
            $relative = '.'
        }
        if ($_.PSIsContainer) {
            Write-Host "[DIR]  $relative"
        }
        else {
            Write-Host "[FILE] $relative"
        }
    }
}

function New-CodexManifest {
    param(
        [System.Collections.IEnumerable] $Records,
        [string] $Path,
        [string] $RepositoryFullName,
        [string] $Branch
    )

    $manifest = [ordered]@{
        repository = $RepositoryFullName
        branch     = $Branch
        generated  = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')
        files      = $Records
    }
    $json = $manifest | ConvertTo-Json -Depth 6
    Set-Content -LiteralPath $Path -Value $json -Encoding UTF8
    Write-Host "Codex manifest saved to $Path" -ForegroundColor Green
}

if ([string]::IsNullOrWhiteSpace($Owner) -or [string]::IsNullOrWhiteSpace($Repository)) {
    throw 'Owner and Repository parameters are required.'
}

$headers = New-GitHubHeaders -Token $Token
$targetPath = Resolve-DestinationPath -Path $Destination -Force:$Force
$repoTree = Get-GitHubTree -Owner $Owner -Repository $Repository -Branch $Branch -Headers $headers

$downloadSummary = @()
foreach ($item in $repoTree | Where-Object { $_.type -eq 'blob' }) {
    $relativePath = $item.path
    Save-GitHubBlob -Owner $Owner -Repository $Repository -Branch $Branch -Path $relativePath -Headers $headers -DestinationRoot $targetPath
    $downloadSummary += [PSCustomObject]@{
        path = $relativePath
        size = $item.size
        sha  = $item.sha
    }
}

Show-RepositoryTree -Path $targetPath
Write-Host "Repository downloaded to $targetPath" -ForegroundColor Green

if (-not [string]::IsNullOrWhiteSpace($CodexManifestPath)) {
    $manifestPath = $CodexManifestPath
}
else {
    $manifestPath = Join-Path -Path $targetPath -ChildPath 'codex_manifest.json'
}

New-CodexManifest -Records $downloadSummary -Path $manifestPath -RepositoryFullName "$Owner/$Repository" -Branch $Branch
