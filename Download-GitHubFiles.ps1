#requires -Version 5.1
<#!
.SYNOPSIS
    지정된 GitHub 저장소에서 파일을 다운로드합니다.

.DESCRIPTION
    GitHub REST API를 사용해 지정된 저장소와 참조(브랜치/태그/커밋)의 트리를 조회하고
    Blob 파일을 개별적으로 내려받습니다. 특정 경로만 선택할 수도 있으며, 다운로드 결과는
    매니페스트(JSON) 파일로 함께 저장됩니다.

.PARAMETER Owner
    GitHub 사용자 또는 조직 이름입니다.

.PARAMETER Repository
    대상 저장소 이름입니다.

.PARAMETER Ref
    다운로드할 브랜치/태그/커밋 참조입니다. 기본값은 'main'입니다.

.PARAMETER DestinationPath
    파일을 저장할 로컬 루트 경로입니다. 기본적으로 현재 디렉터리에
    `<저장소>-<Ref>` 폴더를 생성합니다.

.PARAMETER IncludePath
    다운로드할 경로(상대 경로) 배열입니다. 지정하지 않으면 전체 파일을 내려받습니다.
    와일드카드(`*`, `?`) 패턴을 지원합니다.

.PARAMETER Token
    GitHub API 호출 시 사용할 개인 액세스 토큰입니다(선택 사항).

.EXAMPLE
    .\Download-GitHubFiles.ps1 -Owner example -Repository project -Ref main

.EXAMPLE
    .\Download-GitHubFiles.ps1 -Owner example -Repository project -Ref v1.0 -IncludePath 'docs/*','src/app.ps1'

.NOTES
    - GitHub API 호출 시 User-Agent 헤더가 필수이므로 스크립트에서 기본 값을 지정합니다.
    - IncludePath가 지정된 경우, 경로 비교는 대소문자를 구분하지 않습니다.
!#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Owner,

    [Parameter(Mandatory)]
    [string]$Repository,

    [string]$Ref = 'main',

    [string]$DestinationPath,

    [string[]]$IncludePath,

    [string]$Token
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-GitHubApi {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [hashtable]$Headers,
        [switch]$Raw,
        [string]$OutFile
    )

    $defaultHeaders = @{ 'User-Agent' = 'DataProtectionAutomation' }
    if ($Token) {
        $defaultHeaders['Authorization'] = "token $Token"
    }
    if ($Headers) {
        foreach ($key in $Headers.Keys) {
            $defaultHeaders[$key] = $Headers[$key]
        }
    }

    if ($Raw) {
        return Invoke-WebRequest -Uri $Uri -Headers $defaultHeaders -OutFile $OutFile -UseBasicParsing
    }
    else {
        return Invoke-RestMethod -Uri $Uri -Headers $defaultHeaders -UseBasicParsing
    }
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

if (-not $DestinationPath) {
    $sanitizedRef = $Ref -replace '[^A-Za-z0-9_-]', '_'
    $DestinationPath = Join-Path -Path (Get-Location) -ChildPath ("{0}-{1}" -f $Repository, $sanitizedRef)
}

Ensure-Directory -Path $DestinationPath

Write-Verbose "대상 저장소: $Owner/$Repository ($Ref)"

$commitUri = "https://api.github.com/repos/$Owner/$Repository/commits/$Ref"
try {
    $commitInfo = Invoke-GitHubApi -Uri $commitUri
}
catch {
    throw "GitHub 커밋 정보를 가져오지 못했습니다: $($_.Exception.Message)"
}

$commitSha = $commitInfo.sha
if (-not $commitSha) {
    throw '커밋 SHA를 확인할 수 없습니다.'
}

$treeUri = "https://api.github.com/repos/$Owner/$Repository/git/trees/$commitSha?recursive=1"
try {
    $treeInfo = Invoke-GitHubApi -Uri $treeUri
}
catch {
    throw "GitHub 트리를 가져오지 못했습니다: $($_.Exception.Message)"
}

if (-not $treeInfo.tree) {
    throw '트리 정보가 비어 있습니다.'
}

$patterns = @()
if ($IncludePath) {
    foreach ($pattern in $IncludePath) {
        if (-not [string]::IsNullOrWhiteSpace($pattern)) {
            $patterns += $pattern
        }
    }
}

function Test-MatchPath {
    param(
        [string]$PathValue
    )
    if (-not $patterns -or $patterns.Count -eq 0) {
        return $true
    }
    foreach ($pattern in $patterns) {
        if ($PathValue -like $pattern) {
            return $true
        }
    }
    return $false
}

$downloaded = New-Object System.Collections.Generic.List[object]
$blobs = @($treeInfo.tree | Where-Object { $_.type -eq 'blob' })
if ($blobs.Count -eq 0) {
    Write-Warning '다운로드할 Blob 항목이 없습니다.'
}

foreach ($blob in $blobs) {
    $path = $blob.path
    if (-not (Test-MatchPath -PathValue $path)) {
        continue
    }
    $targetPath = Join-Path -Path $DestinationPath -ChildPath $path
    $parentDir = Split-Path -Path $targetPath -Parent
    Ensure-Directory -Path $parentDir
    $blobUri = "https://api.github.com/repos/$Owner/$Repository/git/blobs/$($blob.sha)"
    try {
        Invoke-GitHubApi -Uri $blobUri -Headers @{ 'Accept' = 'application/vnd.github.v3.raw' } -Raw -OutFile $targetPath | Out-Null
        $downloaded.Add([pscustomobject]@{
            Path = $path
            Sha = $blob.sha
            Size = $blob.size
        })
        Write-Host "[OK] $path" -ForegroundColor Green
    }
    catch {
        Write-Warning "다운로드 실패: $path - $($_.Exception.Message)"
    }
}

$manifest = [pscustomobject]@{
    Repository = "$Owner/$Repository"
    Ref = $Ref
    CommitSha = $commitSha
    GeneratedAt = (Get-Date).ToString('s')
    Destination = (Resolve-Path -LiteralPath $DestinationPath).Path
    FileCount = $downloaded.Count
    Files = $downloaded
}

$manifestPath = Join-Path -Path $DestinationPath -ChildPath 'github_download_manifest.json'
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

Write-Host "총 $($downloaded.Count)개의 파일을 다운로드했습니다." -ForegroundColor Cyan
Write-Host "매니페스트: $manifestPath" -ForegroundColor Cyan
