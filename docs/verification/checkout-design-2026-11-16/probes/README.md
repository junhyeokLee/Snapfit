# 로컬 위젯 검증 대역

이 디렉터리의 Dart/Python 파일은 실행 당시 입력 원본이다. runner의 개별 suite는 checkout, complete, consent, printservice, responsive, journey, cap_checkout, cap_complete다.

SDK 캐시 쓰기·테스트 소켓 제약으로 frontend_server와 flutter_tester를 직접 사용했다. 앱 전체 빌드나 개발 서버는 실행하지 않았다. 엔진·폰트·이미지는 프로젝트와 설치된 Flutter SDK를 사용하며 실제 결제 API는 fixture로 대체한다.

재현 시 파일들을 /tmp/snapfit-checkout-design-20261116에 복사하고 assets/assets를 저장소 assets에 연결한다. FontManifest.json 및 paths.json을 assets/에 두며 fonts/MaterialIcons-Regular.otf는 설치 SDK의 material_fonts 파일로 연결한다. shaders/ink_sparkle.frag 및 shaders/stretch_effect.frag는 SDK material shader를 impellerc --sksl --iplr로 해당 assets/ 경로에 컴파일한다. SDK 소스에 출력 경로를 연결하지 않는다.

사용한 SDK는 /Users/devsheep/flutter이고 패키지 설정은 저장소 .dart_tool/package_config.json이다. frontend_server_aot.dart.snapshot의 --sdk-root는 engine/common/flutter_patched_sdk/, --target=flutter, --packages는 위 패키지 설정이며 --output-dill은 임시 audit.dill이다. compiler 종료 코드와 함께 최종 kernel 기록의 error count 0을 확인했다.

준비된 kernel은 python3 /tmp/snapfit-checkout-design-20261116/run.py checkout '.*' 형태로 suite별 직렬 실행한다. run.py의 stdout뿐 아니라 logs/의 RESULT passed/failed를 확인한다. 캡처는 임시 screens/에 저장한다. 원본 경로를 바꾸면 runner와 캡처 import의 file URI도 함께 맞춘다.

글꼴과 표지 사진은 실제 번들 자원을 쓴다. 캡처 전에 사진 decoder의 IO와 프레임 처리를 기다리고 레이아웃·paint를 갱신해 지연 생성/합성 레이어가 누락되지 않게 했다. 캡처용 album/receipt는 검증용 데이터다.
