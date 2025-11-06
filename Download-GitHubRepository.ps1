#requires -Version 5.1
<#!
    Download and display all files from a GitHub repository.
    -----------------------------------------------------------------
    This script downloads a GitHub repository as a ZIP archive,
    extracts it to a local folder, and prints a tree-style listing
    so that the retrieved files can be reviewed immediately.

    Example
        .\Download-GitHubRepository.ps1 -Repository "owner/project" -Branch main -Destination "C:\Temp\project"
!#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $Repository,
    [string] $Branch = 'main',
    [string] $Destination = (Join-Path -Path $PWD -ChildPath 'github_repo'),
    [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression.FileSystem

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

function Invoke-GitHubDownload {
    param(
        [string] $Repository,
        [string] $Branch,
        [string] $Destination
    )

    $zipPath = Join-Path -Path $env:TEMP -ChildPath ("github_repo_{0}.zip" -f ([Guid]::NewGuid().ToString('N')))
    try {
        $downloadUrl = "https://codeload.github.com/$Repository/zip/$Branch"
        Write-Verbose "Downloading $downloadUrl"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing

        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $Destination)

        $subFolder = Get-ChildItem -LiteralPath $Destination -Directory | Select-Object -First 1
        if ($subFolder) {
            return $subFolder.FullName
        }
        return $Destination
    }
    finally {
        if (Test-Path -LiteralPath $zipPath) {
            Remove-Item -LiteralPath $zipPath -Force
        }
    }
}

function Show-RepositoryTree {
    param([string] $Path)

    Write-Host "--- Repository contents ---" -ForegroundColor Cyan
    Get-ChildItem -LiteralPath $Path -Recurse | ForEach-Object {
        $relative = Resolve-Path -LiteralPath $_.FullName | ForEach-Object { $_.Path }
        $relative = $relative.Substring($Path.Length).TrimStart('\','/')
        $prefix = if ([string]::IsNullOrEmpty($relative)) { '.' } else { $relative }
        if ($_.PSIsContainer) {
            Write-Host "[DIR]  $prefix"
        }
        else {
            Write-Host "[FILE] $prefix"
        }
    }
}

if (-not ($Repository -match '.+/.+')) {
    throw "Repository must be in the form 'owner/name'."
}

$targetPath = Resolve-DestinationPath -Path $Destination -Force:$Force
$repoRoot = Invoke-GitHubDownload -Repository $Repository -Branch $Branch -Destination $targetPath
Show-RepositoryTree -Path $repoRoot

Write-Host "Repository downloaded to $repoRoot" -ForegroundColor Green
