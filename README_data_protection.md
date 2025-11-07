# 데이터 보호 평가 도구 모음

## PowerShell 스크립트

### `data_protection_assessment_v_0.1.ps1`
- 일반/보안 영역을 초기화하고 Atomic·RanSim 기반 시뮬레이션을 수행해 CSV/JSON/XLSX/DOCX 보고서를 생성합니다.
- 관리자 권한의 PowerShell 5.1 이상에서 실행해야 하며, 테스트 전용 환경에서 사용하세요.

### `data_protection_assessment_v_0.6.ps1`
- 0.1 버전을 개선한 평가 자동화 스크립트입니다.
- 동일하게 PowerShell 5.1 이상 및 테스트 전용 환경에서 실행합니다.

### `Download-GitHubFiles.ps1`
GitHub 저장소와 연동해 원하는 참조(브랜치/태그/커밋)의 파일을 내려받고 매니페스트를 생성합니다.

```powershell
# 전체 저장소 다운로드
pwsh -File .\Download-GitHubFiles.ps1 -Owner example -Repository project -Ref main

# 특정 경로만 선택적으로 다운로드
pwsh -File .\Download-GitHubFiles.ps1 -Owner example -Repository project -Ref v1.0 \
    -IncludePath 'docs/*','src/app.ps1'

# 개인 액세스 토큰 사용
pwsh -File .\Download-GitHubFiles.ps1 -Owner example -Repository project -Token (Get-Content token.txt)
```

실행이 완료되면 `<저장소>-<참조>` 폴더 아래에 실제 파일과 `github_download_manifest.json`이 생성됩니다.
