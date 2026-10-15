# 스냅핏 인쇄 작업의 Linux 상시 실행 준비

2026-10-15 변경: 신규 고객 주문은 [앱 PDF 생성·업로드 후 Supabase 자동 발주](supabase-app-pdf-orders-2026-10-15.md)를 사용한다. 별도 PDF 생성 호스트를 설치하거나 결제하지 않았다. 아래 서버 생성/호스트 안내는 이전 대안의 준비 기록이다.

이 문서는 제공업체와 관계없이 사용할 Linux/systemd 배포 패키지 안내입니다. 현재 실제 운영 호스트와 작업 계정은 정하지 않았으며, 서비스를 설치하거나 상시 실행하지 않았습니다. 로컬 구문·설정 검증과 실제 Linux 운영 검증을 구분합니다.

## 준비한 파일

`tool/print_fulfillment/linux`에 설정 검사 도구, 서비스 템플릿, 설치 스크립트와 환경파일 이름 예시를 추가했습니다. 기존 Node 작업 실행기와 실제 Flutter 앨범 렌더러를 그대로 사용합니다. 공급업체·결제 API, SDK, 앱 번들, 운영 승인 조건은 변경하지 않습니다.

| 파일 | 역할 |
| --- | --- |
| `check-linux-host.mjs` | 경로, 기존 비관리자 OS 계정/그룹, Node 22 이상, 캐시된 Flutter 3.44 이상과 해당 Linux 엔진, 준비된 앱 의존성 검사 |
| `snapfit-print-worker.service.in` | 고정 실행 폴더, 실패/종료 후 재시작, 작업 프로세스 전체 정리, 비공개 임시 폴더 설정 |
| `install-linux-service.sh` | 설정과 systemd 구문을 검증한 뒤 서비스 파일 등록. 기본적으로 시작·부팅 자동 실행을 켜지 않음 |
| `worker.env.example` | 필요한 환경변수 이름과 `REPLACE_` 표시만 제공. 실제 인증 값은 없음 |

설치 도구는 SDK/OS 패키지를 내려받거나 OS/Auth 계정을 만들지 않습니다. 필요한 Node·Flutter와 캐시/앱 의존성이 이미 준비된 경로를 입력해야 합니다. Flutter의 Linux 기본 환경은 [공식 설치 안내](https://docs.flutter.dev/install/manual)를 참고합니다.

## 인증 값과 파일 권한

실제 환경파일은 저장소 밖의 호스트 전용 위치에 준비합니다. 예시 이름은 `/etc/snapfit-print/worker.env`입니다. 파일은 **root 소유·0600**이어야 하며, 심볼릭 링크나 저장소 내부 경로는 검사에서 거부합니다. 검사 도구는 파일 종류·소유자·권한만 확인하고 내용을 열거나 출력하지 않습니다. 비밀번호·JWT·API 키를 명령 인수로 받지 않습니다.

기존 작업 실행기는 Supabase 공개 프로젝트 키와 정상 작업 계정의 이메일/비밀번호로 로그인하고 세션을 메모리에서 갱신할 수 있습니다. 호스트를 재시작해도 새 세션으로 시작하려면 이 방법을 사용합니다. 실제 계정은 서버가 확인하는 `print_worker` 또는 관리자 권한이 있어야 합니다. 이번 준비에서 계정과 인증 값을 만들지 않았습니다.

환경파일에는 `SNAPFIT_SUPABASE_URL`, `SNAPFIT_SUPABASE_PUBLISHABLE_KEY`, `SNAPFIT_PRINT_WORKER_EMAIL`, `SNAPFIT_PRINT_WORKER_PASSWORD` 이름만 필요합니다. 내용은 호스트 비밀 설정에서 직접 채웁니다. PortOne·레드프린팅·Supabase 서비스 키는 이 호스트 파일로 옮기지 않습니다.

서비스는 systemd가 환경파일을 읽은 뒤 실행 프로세스에서는 해당 파일 경로를 숨깁니다. 작업/임시 폴더는 0700, 새 파일 기본 권한은 0600입니다. Flutter 자식 프로세스에 작업 계정·결제·공급업체 인증 환경을 전달하지 않는 기존 처리를 유지합니다. 로그는 기존 실행기의 처리 수·단계와 고정 오류 코드만 남기며, 원본 사진 URL·연락처·주소·인증 값·원문 응답은 출력하지 않습니다. 이 설정은 [systemd 실행 환경 명세](https://raw.githubusercontent.com/systemd/systemd/main/man/systemd.exec.xml)에 따른 서비스 파일입니다.

## 호스트에서 설정을 확인하고 등록하는 순서

아래 경로와 `snapfit-worker`는 실제 호스트를 선택한 뒤 바꿀 예시입니다. 계정/그룹은 이미 존재해야 하며, Flutter 캐시와 앱의 `.dart_tool`/`build` 및 의존성 폴더를 그 계정에서 사용할 수 있어야 합니다. macOS의 작업 경로를 Linux에 그대로 복사해 실행하지 않습니다.

```bash
sudo /opt/node/bin/node -- tool/print_fulfillment/linux/check-linux-host.mjs \
  --check-install \
  --project-dir /opt/snapfit/app \
  --node-bin /opt/node/bin/node \
  --flutter-bin /opt/flutter/bin/flutter \
  --pub-cache-dir /home/snapfit-worker/.pub-cache \
  --service-user snapfit-worker \
  --service-group snapfit-worker \
  --worker-env-path /etc/snapfit-print/worker.env
```

설정 검사는 API 인증·결제·발주를 호출하지 않습니다. 실제 환경값을 읽지 않으므로, 통과했다는 결과는 키와 계정이 유효하거나 업체 운영 승인이 끝났다는 뜻이 아닙니다. 제공된 경로/런타임/권한이 준비됐는지 확인하는 단계입니다. 파일 경로 옵션은 Node 자체 환경파일 로딩 옵션과 겹치지 않도록 `--worker-env-path`를 사용하며, Node와 스크립트 사이에는 `--` 경계를 둡니다.

```bash
sudo bash tool/print_fulfillment/linux/install-linux-service.sh \
  --project-dir /opt/snapfit/app \
  --node-bin /opt/node/bin/node \
  --flutter-bin /opt/flutter/bin/flutter \
  --pub-cache-dir /home/snapfit-worker/.pub-cache \
  --service-user snapfit-worker \
  --service-group snapfit-worker \
  --worker-env-path /etc/snapfit-print/worker.env
```

등록 대상은 `snapfit-print-worker.service`로 고정합니다. 기존 파일이 있으면 기본적으로 덮어쓰지 않으며, 검토한 변경을 적용할 때만 `--replace`를 지정합니다. 등록은 서비스 파일 복사와 systemd 설정 재조회까지만 진행합니다. 결제·제작 운영 설정은 계속 별도로 닫아 둡니다.

## 실제 실행에서 추가로 확인할 내용

선택한 Linux 호스트에서 고객 데이터 없는 `--fixture` 렌더 검증을 먼저 실행해야 합니다. `SOFT_20`은 200×150mm 소프트커버 20쪽, `HARD_80`은 300×300mm 하드커버 80쪽입니다. 모든 내지에 합성 카드·글 레이어가 들어가며, 운영·실물 승인으로 취급하지 않습니다. 기본 하드커버 fixture는 압축 가능한 `compact` 카드입니다. 원본의 복잡한 카드를 반복하는 용량 한계 시험은 `--fixture-artwork standard`로 재현합니다.

```bash
SNAPFIT_FLUTTER_BIN=/opt/flutter/bin/flutter /opt/node/bin/node -- \
  tool/print_fulfillment/run_worker.mjs --fixture --fixture-scenario SOFT_20
SNAPFIT_FLUTTER_BIN=/opt/flutter/bin/flutter /opt/node/bin/node -- \
  tool/print_fulfillment/run_worker.mjs --fixture --fixture-scenario HARD_80
```

이 경로에서는 작업 계정 인증·PG·공급업체 호출을 하지 않습니다. Flutter 버전 자동 확인과 통계 수집을 끄고 `--no-pub`로 준비된 의존성을 사용합니다. 새 PDF를 동일한 서버 검수기에 검사하고, 20쪽과 80쪽의 실제 처리 시간·메모리·임시 공간·글꼴을 확인합니다. 이 확인 전 호스트가 렌더 준비됐다고 표시하지 않습니다.

PDF 작성기는 누적 JPEG 90MiB, 저장/업로드 경로는 파일별 100MiB 한계를 유지합니다. JPEG 품질 95와 300dpi를 낮춰 이 제한을 통과시키지 않습니다. macOS에서 복잡한 카드로 하드커버 80쪽을 요청한 시험은 약 132초·최대 RSS 868MB에서 `print_pdf_exceeds_90mb_limit`로 중단됐으며, 완성 PDF는 생성되지 않았습니다. `output/pdf/print-worker-hard300-80-fixture-2026-10-14/dense-artwork-limit-*.json`에 실패 증거를 남겼습니다. 압축 가능한 카드 80쪽의 성공도 모든 고객 사진 분량이 이 한계에 들어간다는 보장은 아닙니다. 고객 결제 전에는 동일 PDF 생성/용량 검수에 통과한 내용만 사용해야 합니다.

같은 macOS에서 `compact` 하드커버 80쪽 실제 렌더는 표지 1,221,664B·내지 60,200,362B로 완료됐습니다. 전체 측정 약 292초·최대 RSS 666MB였으며 표지/첫 페이지/80페이지 PNG에서 한글·카드·페이지 번호를 확인했습니다. 이 PDF를 실제 서버 PDF 검사기에 검사하고, 로컬 가짜 PG/DB/공급업체로 접수→파일 확인 Y→제작→송장 흐름을 연결했습니다. 제출·예치금 stub 호출은 각각 1회이며 최종 상태는 배송중입니다. 실제 결제·발주·발송과 실물 승인은 없습니다. 성공 PDF·지문·검수 보고서·PNG도 같은 출력 폴더에 저장했습니다.

승인된 호스트에서 서비스를 시작하려면 `sudo systemctl enable --now snapfit-print-worker.service`를 사용합니다. 중지와 재시작은 `systemctl stop`/`restart`로 제어합니다. `Restart=always`, `RestartSec=30` 설정은 프로세스가 끝나면 다시 실행하며, 사용자가 명시적으로 서비스를 중지하면 중지 상태를 유지합니다. 개별 작업 오류의 재조회는 기존 실행기가 담당하고, 프로세스 중단은 systemd가 담당합니다. 전체 프로세스 그룹을 중지하므로 중단된 Flutter가 따로 남지 않도록 설정했습니다. [systemd 서비스 명세](https://raw.githubusercontent.com/systemd/systemd/main/man/systemd.service.xml)

실제 실행 후에는 일반 Auth 로그인, 서버가 확인한 권한, 운영 설정이 닫힌 상태의 무발주 반복 실행, 프로세스 실패 후 재시작, 호스트 재부팅 후 실행, 인증 세션 갱신을 확인합니다. 실행 기록이 끊겼을 때 고객 결제가 닫히는 서버 조건도 확인해야 합니다. 서비스가 실행 중이라는 표시만으로 결제/렌더/업체 접수가 모두 준비됐다고 간주하지 않습니다.

렌더 취소/시간 초과는 Unix 프로세스 그룹 전체에 종료 신호를 보내고, 5초 뒤 강제 종료합니다. 프로세스 종료·출력 스트림 정리가 확인된 뒤에만 임시 파일을 지웁니다. 작업 도중 실패한 렌더가 다음 작업과 함께 남아 쓰기를 계속하지 않도록 처리했습니다. [Node 자식 프로세스 명세](https://nodejs.org/api/child_process.html)

인증 갱신이 겹치면 한 번의 갱신 결과를 공유합니다. 서버가 401을 응답하면 정상 갱신/로그인 뒤 같은 요청을 한 번만 다시 보내고, 다시 실패하면 오류를 기록합니다. 작업·업체 주문 식별자를 바꾸거나 예치금 불확정 요청을 새 발주로 바꾸지 않습니다. 이는 로컬 Auth/stub 회귀로 검증했으며 실제 운영 계정 인증을 완료한 것은 아닙니다.

각 작업 주기에서 결제 재확인 다음에 취소/환불 요청 복구 tick을 1건 호출하고, 그 뒤 제조 보류 조건이 적용된 작업을 조회합니다. 요청 복구가 실패하면 안전한 오류 코드와 0건 집계를 호스트 로그에 남깁니다. 실제 환불 운영 설정은 닫혀 있으며, 검증 fixture의 요청 복구 endpoint도 비운영 stub입니다.

현재 macOS 환경에서 Docker/Colima/Podman/Lima/Multipass/QEMU 명령, 주요 VM 앱 및 기존 Colima/Lima 상태 폴더를 확인하지 못했습니다. 새 설치·유료 호스트·계정 생성 없이 실제 Linux 실행을 검증할 경로는 확보되지 않았습니다. 호스트 설정 검사도 macOS에서 Linux 전용 오류로 안전하게 종료되는 것을 확인했습니다.

실제 Linux의 `systemd-analyze verify`, 서비스 설치/시작/재시작/부팅 복구, Linux Flutter 렌더와 상시 실행은 **미검증**입니다. 서비스 파일 준비와 macOS 합성 검증은 운영 키·사업자등록·계약·최종 배송/가격·실물 샘플 승인을 대신하지 않습니다.
