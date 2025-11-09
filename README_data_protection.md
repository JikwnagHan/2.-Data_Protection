# data_protection_assessment_v_0.6.ps1 사용 가이드

`data_protection_assessment_v_0.6.ps1`는 일반 영역(GeneralArea)과 보안 영역(SecureArea)에 동일한 테스트 데이터를 배치한 뒤, Atomic Red Team(악성코드)와 RanSim(랜섬웨어) 시뮬레이션을 자동 실행하여 데이터 보호 성능을 검증하는 PowerShell 스크립트입니다. 스크립트는 관리자 권한 PowerShell 콘솔에서 단계별 안내를 출력하며, 결과는 CSV / JSON / XLSX / DOCX 형태의 보고서로 생성됩니다.

---

## 주요 기능

| 카테고리 | 설명 |
| --- | --- |
| 경로 입력 자동화 | 일반 영역, 보안 영역, 결과 저장 위치(폴더 또는 `.xlsx` 파일 경로)를 순차적으로 입력받고, 누락 시 재입력을 요청합니다. |
| 테스트 데이터 재구성 | 두 영역의 기존 파일을 삭제한 뒤, 9종 문서(`.doc`, `.docx`, `.ppt`, `.pptx`, `.xls`, `.xlsx`, `.hwp`, `.hwpx`, `.txt`)와 시스템 파일(hosts, system.env 등)을 동일하게 재생성합니다. |
| 시뮬레이터 점검 | RanSim 실행 파일, Invoke-AtomicRedTeam 모듈/Atomics, Caldera PATH를 확인하고 없을 경우 자동 다운로드를 시도합니다. 네트워크가 막혀 있으면 수동 경로를 안내합니다. |
| 악성코드 평가 | Atomic Red Team의 7개 대표 영역으로 구성된 30개 기법을 실행하거나 스크립트에서 모의 수행하여 파일 변화(Exists/Size/Hash)를 추적합니다. |
| 랜섬웨어 평가 | RanSim을 호출하여 암호화를 시뮬레이션하고, 영역별 변경/신규/누락 파일 수를 CSV/JSON으로 기록합니다. |
| 보고서 생성 | Baseline, Malware, Ransomware CSV 및 JSON, 요약 CSV, Excel 요약(`DataProtection_Report_*.xlsx`), Word 분석(`DataProtection_Report_*.docx`)을 자동 생성합니다. |

---

## 시스템 요구 사항

- Windows PowerShell 5.1 이상 또는 PowerShell 7.x
- 관리자 권한 PowerShell 콘솔 (테스트 경로 삭제/재생성)
- 인터넷 연결 (시뮬레이터 자동 설치 시 필요)
- 테스트 전용 드라이브/폴더 (스크립트가 지정 경로 전체를 초기화)

---

## 빠른 시작

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\data_protection_assessment_v_0.6.ps1
```

1. **경로 입력**  
   - 일반 영역 드라이브/경로  
   - 보안 영역 드라이브/경로  
   - 결과 저장 위치 (폴더 or `.xlsx` 파일 경로)  
   결과 경로가 폴더이면 `DataProtection_Report_yyyyMMdd_HHmmss.xlsx/.docx`를 자동 생성하고, `.xlsx` 파일명을 입력하면 해당 파일명으로 보고서를 만듭니다.
2. **자동 실행 흐름**  
   영역 초기화 → 샘플 데이터 생성 → 시뮬레이터 점검/설치 → 악성코드 평가 → 랜섬웨어 평가 → 보고서 출력
3. **결과 확인**  
   종료 메시지 또는 결과 폴더에서 CSV/JSON/XLSX/DOCX 산출물을 확인합니다.

---

## 평가 워크플로

1. **영역 초기화 및 샘플 생성**  
   - 지정된 두 루트(GeneralArea, SecureArea)를 비우고 문서 9종 + 시스템/환경 파일 5종을 동일하게 생성합니다.  
   - 각 파일의 크기와 SHA256을 Baseline CSV에 기록합니다.
2. **기준 무결성 측정**  
   - 초기 상태 스냅샷을 수집하여 `csv/Baseline_*.csv`에 저장합니다.
3. **악성코드 평가(Atomic)**  
   - 7개 버킷, 30개 대표 기법을 실행(또는 모의)하고, 시나리오 전후 스냅샷을 비교해 `csv/Malware_Assessment_*.csv` 및 요약(`*_Summary_*.csv`)을 생성합니다.
4. **랜섬웨어 평가(RanSim)**  
   - RanSim을 실행하여 변경/신규/누락 파일을 집계하고 `csv/Ransomware_Assessment_*.csv`, `json/Ransomware_Evaluation_Details_*.json` 등을 생성합니다.
5. **보고서 작성**  
   - **XLSX**: Baseline/Malware/Ransomware 시트를 포함한 요약 통계 (`DataProtection_Report_*.xlsx`)  
   - **DOCX**: 환경 정보, 시뮬레이터 상태, 단계별 결과 해석, 권고 사항을 정리한 분석 보고서 (`DataProtection_Report_*.docx`)

---

## 생성 파일 목록

```
csv/Baseline_*.csv
csv/Malware_Assessment_*.csv
csv/Malware_Assessment_FileStatus_*.csv
csv/Malware_Assessment_Summary_*.csv
csv/Ransomware_Assessment_*.csv
csv/Ransomware_FileStatus_*.csv
json/Malware_Assessment_Details_*.json
json/Ransomware_Evaluation_Details_*.json
DataProtection_Report_*.xlsx
DataProtection_Report_*.docx
```

---

## 자주 발생하는 이슈와 대응

| 증상 | 원인 | 해결 방법 |
| --- | --- | --- |
| RanSim 자동 설치 실패 | TLS 차단/인증서 문제 | 사내 프록시 예외를 구성하거나 공식 사이트에서 설치 파일을 받아 경로 입력 |
| Atomic 모듈/Atomics 폴더 누락 | GitHub 차단 또는 설치 경험 없음 | `Install-Module Invoke-AtomicRedTeam -Force` 실행 후 `ATOMIC_RED_TEAM_PATH` 또는 `C:\AtomicRedTeam\atomics` 지정 |
| Caldera PATH 미설정 | 로컬 경로 확인 불가 | 사전 설치 후 `CALDERA_PATH` 환경 변수 또는 입력 프롬프트에 풀 경로 지정 |
| 일반/보안 경로가 동일 | 같은 경로 입력 | 서로 다른 드라이브 혹은 상위 폴더를 지정해야 스크립트가 실행됩니다. |

---

## 안전 수칙

- 실제 운영 데이터를 대상으로 실행하지 마십시오.  
- RanSim/Atomic/Caldera 실행은 보안 솔루션 정책에 영향을 줄 수 있으니 테스트 전용 장비에서 사용하십시오.  
- 생성된 보고서에는 경로와 해시 값이 포함되므로 외부 반출 시 내부 보안 정책을 준수하십시오.

---

추가 개선 사항이나 이슈는 저장소 이슈 트래커를 통해 제보해 주세요.
