# Data Protection Compensation Scripts

현재 저장소에는 아래와 같이 세 가지 버전의 보상 자동화 스크립트만 포함되어 있습니다. 이전에 존재하던 GitHub 연동 스크립트나 초기 평가 스크립트는 삭제되었습니다.

| 파일 | 설명 |
| --- | --- |
| `data_protection_Compensation_v_0.1.ps1` | 기본 데이터 재구성, 악성 행위 시뮬레이션, 보고서 생성을 수행하는 초판 스크립트 |
| `data_protection_Compensation_v_0.2.ps1` | 드라이브 문자 유효성 검사와 경로 자동 구성을 추가한 개선 버전 |
| `data_protection_Compensation_v_0.3.ps1` | 요약 보고서 형식을 확장하고 결과 문서를 고정 경로로 생성하는 최신 버전 |

각 스크립트는 PowerShell 5.1 이상 환경에서 관리자 권한으로 실행해야 하며, 테스트 전용 환경에서의 사용을 권장합니다.
