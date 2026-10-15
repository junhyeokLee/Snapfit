# 스냅핏 인쇄 워커의 Railway 배포 준비

확인일: 2026년 10월 15일. **사용자는 개발 단계에서 추가 비용을 원하지 않아 상시 서버 도입을 출시 전으로 미뤘습니다. 지금 Railway 가입·카드 등록·구독·호스트 배포를 진행하지 않습니다.** 현재 PC에서 합성 PDF와 개발 주문을 테스트하며 기존 Supabase를 유지합니다. 아래 내용은 추후 필요할 때 검토할 후보 설정입니다. 실제 판매는 계속 닫혀 있습니다.

## 기존 Supabase와 역할

주문 데이터·개인 파일·결제 및 업체 인증·주문상태 처리는 기존 Supabase 프로젝트에 둡니다. Railway 후보에는 실제 Flutter 앨범 PDF를 만드는 워커 서비스 1개만 둡니다. 추가 DB·Redis·영구 볼륨·공개 웹 주소·이미지 저장소는 만들지 않습니다. 워커는 기존 Supabase 주문 큐와 저장소를 이용해 한 번에 한 앨범을 처리합니다.

현재 렌더러는 Flutter `test`/`flutter_tester`를 이용하고, 사진을 300dpi로 렌더링해 PDF로 저장합니다. macOS 합성 하드커버 80페이지 시험은 약 5분·최대 RSS 666MB, 용량 제한 실패 시험은 최대 RSS 868MB였습니다. 이를 Supabase Edge Function에 그대로 옮길 수는 없습니다. Edge Function의 메모리·CPU 시간 제한과, 고객 기기에서 만든 검수 완료 PDF를 서버가 재사용할 수 있는지는 서로 다른 문제입니다. [Supabase Edge Function 제한](https://supabase.com/docs/guides/functions/limits)

## 준비한 설정

`tool/print_fulfillment/railway/.railway/railway.ts`에 비밀값 없는 Infrastructure as Code(IaC) 설정을 둡니다.

| 설정 | 준비값 |
| --- | --- |
| 서비스 | `snapfit-print-worker` 한 개 |
| 빌드 | 배포 폴더의 `Dockerfile` |
| 지역 | Singapore `asia-southeast1-eqsg3a` |
| 복제 수 | 1 |
| CPU 상한 | 2 vCPU |
| 메모리 상한 | 4GiB |
| 자동 휴면 | 끔 |
| 재시작 | 프로세스 종료 시 `ALWAYS` |
| 배포 중 중첩 시간 | 0초 |
| 종료 유예 | 30초 |

CPU·메모리 상한은 사용할 수 있는 최대량입니다. 설정한 자원을 항상 쓰거나 월 정액으로 선불 구매하는 것이 아닙니다. 실제 렌더 작업의 메모리·시간·임시 저장 공간은 선택한 Linux 호스트에서 다시 검증해야 합니다. [리소스 상한과 비용](https://docs.railway.com/pricing/cost-control), [지역](https://docs.railway.com/deployments/regions), [재시작](https://docs.railway.com/deployments/restart-policy)

신규 Railway 서비스는 `railway.json`/`railway.toml` 형식의 Config as Code를 선택할 수 없습니다. 기존 서비스도 2026년 12월 1일부터 이 파일을 읽지 않습니다. 이번 준비는 `.railway/railway.ts`와 `railway config plan/apply`를 사용합니다. [공식 IaC 안내](https://docs.railway.com/infrastructure-as-code), [필드 참조](https://docs.railway.com/infrastructure-as-code/reference)

배포 도구는 `railway@3.16.0`, `@railway/cli@5.68.0`로 고정하고 `package-lock.json`의 공개 npm 무결성 값을 검증합니다. 작업 런타임 Node 버전은 Linux 런타임 기록과 같은 `24.21.0`입니다. 이 도구 패키지는 앱이나 PDF 워커 런타임이 아니며, 배포 설정을 준비하는 로컬 도구입니다. [CLI 설치](https://docs.railway.com/cli)

고정 버전의 CLI를 사용할 때에는 `RAILWAY_NO_AUTO_UPDATE=1`로 자동 CLI·관리 스킬 업데이트를 끕니다. 자동 스킬 설치나 별도 Railway Agent 설정은 진행하지 않습니다. [공식 CLI 패키지](https://www.npmjs.com/package/%40railway/cli)

## 비용

Railway Hobby는 월 최소 **미화 5달러**이며 이 금액에 사용량 5달러가 포함됩니다. 사용량이 3달러면 총액은 5달러, 사용량이 7달러면 총액은 7달러입니다. 항상 기본료와 전체 사용료를 더하는 구조가 아닙니다. 현재 공개 요금은 RAM 약 10달러/GB·월, CPU 약 20달러/vCPU·월, 서비스 외부 전송 0.05달러/GB입니다. [현재 요금](https://railway.com/pricing), [포함 사용량과 계산 예](https://docs.railway.com/pricing/plans)

이 워커가 초기 적은 주문량에서 월 5~10달러 안에 들어갈 가능성은 있지만, 실제 Linux 배포·1주일 사용량 확인 전에 이를 고정 비용으로 약속할 수 없습니다. 실제 비용은 대기 메모리, 컴파일·렌더 시간, 사진 다운로드와 PDF 업로드량에 따라 달라집니다. 원화 환산, 세금, 카드 환전 수수료는 별도입니다. 기존 Supabase 사용료도 이 서버 가격에 포함되지 않습니다. [공식 비용 확인 방법](https://docs.railway.com/pricing/faqs)

무료 플랜의 0.5GB RAM과 Trial의 1GB RAM은 현재 렌더러의 컴파일 여유까지 확인한 상시 운영 환경이 아닙니다. 무료·Trial에는 `ALWAYS` 재시작도 제공되지 않습니다. 무료 자동 휴면 서비스를 상시 서버로 안내하지 않습니다. [플랜 제한](https://docs.railway.com/pricing/plans)

가입·유료 선택 후 사용량을 제한할 경우에는 Compute 이메일 알림 7달러·중지 한도 10달러를 제안합니다. 이 설정은 **워크스페이스 전체** CPU·메모리·저장·외부 전송 사용량에 적용되며, Railway Agent 사용량은 별도입니다. 이 워커 준비에서는 Railway Agent를 쓰지 않습니다. 세금·환전 수수료까지 포함한 최종 원화 청구 상한을 의미하지 않습니다.

```bash
railway usage limit set --target workspace --soft 7 --hard 10 --json
```

최소 이메일 알림은 5달러, 최소 중지 한도는 10달러이며 정수 달러만 지원합니다. **중지 한도에 도달하면 서비스가 꺼집니다.** 개발 준비 중 예산 보호에는 사용할 수 있지만 실제 판매를 열기 전에는 예상 주문량에 맞춘 한도와 워커 실행 기록이 끊길 때 결제가 차단되는 동작을 함께 확인해야 합니다. [사용량 명령](https://docs.railway.com/cli/usage), [한도 동작](https://docs.railway.com/pricing/cost-control)

## 출시 전에 Railway를 선택할 경우의 직접 단계

Railway 방식으로 결정한다면 사용자는 가입·이메일 또는 로그인 인증, 결제 카드 등록과 Hobby 유료 선택, CLI 연결의 브라우저 인증만 직접 완료하면 됩니다. 카드 번호·비밀번호·토큰을 채팅으로 보내지 않습니다. 가입만 하는 무료 단계와 유료 플랜 선택을 구분하며, 아직 유료 선택이나 비용 발생을 진행하지 않았습니다. [계정 및 카드](https://docs.railway.com/pricing/faqs), [CLI 로그인](https://docs.railway.com/cli/login)

그 이후 서비스 생성, 설정 미리보기, 배포, 환경 설정, 사용량 알림과 실제 렌더 검증은 에이전트가 이어서 진행할 수 있습니다. 현재 코드를 그대로 공개 저장소에 업로드하지 않습니다. 검토된 파일만 들어 있는 격리 배포 폴더를 로컬 CLI로 전송하며 기존 Git 커밋·공개 저장소·이미지 레지스트리가 필요하지 않습니다. [로컬 폴더 배포](https://docs.railway.com/cli/deploying)

## 비밀 설정과 실행 전 순서

인증값은 IaC 파일이나 배포 폴더에 넣지 않습니다. 워커에는 Supabase 프로젝트 공개 키와 전용 작업 계정 로그인만 필요하며, PortOne·레드프린팅·Supabase 서비스 키를 복사하지 않습니다. 계정과 실제 서버 설정 준비 결과는 아래 운영 기록에 별도로 추가합니다.

배포 도구는 별도 로컬 폴더에서 잠금 파일 기준으로 설치합니다. 인증한 뒤 정확한 새 프로젝트·환경을 선택하고 `railway config plan`의 결과가 워커 한 개만 생성·설정하는지 확인합니다. 예상하지 않은 DB·볼륨·공개 주소·기존 서비스 삭제가 표시되면 적용하지 않습니다. 전체 프로젝트 IaC는 선언에서 빠진 리소스를 삭제할 수 있으므로 다른 서비스가 있는 프로젝트에 그대로 적용하지 않습니다.

환경변수는 값이 명령 인수나 출력에 남지 않게 `railway variable set KEY --stdin --skip-deploys`로 한 키씩 전달합니다. CLI의 `variable list --kv/--json`은 비밀값이 표시될 수 있으므로 확인용으로 실행하지 않습니다. 성공한 설정 명령은 키 이름만 출력합니다. 전체 `.env` 또는 JSON 맵의 stdin import를 지원한다고 가정하지 않습니다. [변수 명령](https://docs.railway.com/cli/variable)

서비스에 인증값을 전달하기 전에 Docker 이미지에서 고객 데이터 없는 20·80페이지 fixture 렌더와 PDF 검수를 확인합니다. 이후 운영 설정이 닫힌 상태의 작업 계정 인증·반복 실행·재시작·세션 갱신을 확인하고, 실제 비용 예상과 워커 실행 기록을 검증합니다. 사업자등록·운영 계약과 키·예치금·실물 승인·실결제 검증은 별도 출시 조건입니다.

## 검증 범위와 운영 기록

IaC 설정은 고정한 공식 SDK로 직접 평가해 서비스 수·실제 정규화된 리소스 상한·지역·휴면 해제·재시작·중첩 시간 0을 검사합니다. 평가 중 API 호출이 없고 인증값이나 추가 유료 리소스가 선언되지 않는지 확인합니다. 이 로컬 검증은 Railway 서버 생성, Docker 빌드, 실제 Linux 렌더나 상시 실행을 확인한 결과가 아닙니다.

2026년 10월 15일 로컬 IaC 검사 5건이 통과했습니다. 테스트는 공식 SDK `3.16.0`과 고정 잠금 파일을 사용하는 임시 도구 폴더에서 실행했고, CLI 설치 스크립트·계정 연결·외부 배포는 실행하지 않았습니다. 테스트를 실행한 macOS Node는 `24.19.0`이며, 운영 대상 Linux의 고정 Node `24.21.0` 실행과는 구분합니다.

실제 가입·유료 선택·Railway 배포·상시 실행·재부팅/장애 복구·운영 결제/제작은 **미검증**입니다. Dockerfile과 실행 전 검사도 후보 준비 파일이며 현재 컴퓨터에 Docker/Linux 실행 환경이 없어 실제 이미지 빌드나 Linux fixture 실행을 하지 않았습니다. 향후 격리 배포 폴더 구성과 실제 이미지 검증을 마친 뒤에만 적용합니다.

같은 날 기존 Supabase에 `print_worker` 전용 계정을 만들고 정상 로그인 및 현재 Auth 역할 확인을 완료했습니다. 인증값은 저장소·앱·채팅에 남기지 않고 저장소 밖 비공개 준비 파일에만 보관했습니다. 이 계정으로 판매 비활성 상태에서 작업 주기를 1회 호출했고 `enabled=false`, 처리 0건, 취소·환불 처리 0건을 확인했습니다. 외부 초대 메일, 운영 키 변경, 실제 결제·제작은 없습니다. 상시 서비스를 시작하거나 반복 실행을 등록하지 않았습니다. 추후 배포 시 유효한 비밀값 전달 또는 안전한 재설정을 다시 확인합니다.

Supabase 단독 구조는 고객 앱에서 결제 전 실제 PDF를 생성해 비공개 저장소에 확정하고 이후 발주를 Cron으로 처리하도록 변경하면 가능합니다. 현재 구현은 결제 후 신뢰한 워커가 원본 앨범에서 PDF를 다시 만드는 방식이므로 Cron만 추가해서 대체할 수 없습니다. 결제 전 파일 묶음의 소유자·앨범·사양·해시·금액 연결, 변경 금지, 미결제 파일 정리와 실제 휴대폰·Edge 자원 검증이 필요합니다. Free 파일당 50MB 제한은 실제 60.2MB 하드커버 fixture보다 작으며, 기존 프로젝트 플랜을 확인하지 않고 추가비용 0원으로 전체 80쪽 지원을 보장할 수 없습니다. 이번에 이 설계 변경이나 저장소 유료 전환을 진행하지 않았습니다. [Storage 제한](https://supabase.com/docs/guides/storage/uploads/file-limits)
