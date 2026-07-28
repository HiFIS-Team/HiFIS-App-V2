# HiFIS-App-V2

[ HiFIS-V2ㅣApp ] 피트니스스타 직원 관리 플랫폼

## 소개

피트니스스타 직원 관리 플랫폼의 모바일 앱(HiFIS V2)입니다.

## 기술 스택

- **Framework**: Flutter 3.44.4 (stable)
- **Language**: Dart 3.12.2
- **지원 플랫폼**: Android, iOS

## 요구 사항

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.44 이상
- Android 빌드: Android Studio + Android SDK
- iOS 빌드: macOS + Xcode + CocoaPods

설치 환경 점검:

```bash
flutter doctor
```

## 시작하기

```bash
# 1. 저장소 클론
git clone <repository-url>
cd HiFIS-App-V2

# 2. 의존성 설치
flutter pub get

# 3. 실행 (연결된 기기 또는 에뮬레이터)
flutter run
```

특정 기기를 지정해 실행하려면:

```bash
flutter devices          # 사용 가능한 기기 목록 확인
flutter run -d <device-id>
```

## 빌드

### Android

```bash
# APK (테스트 배포용)
flutter build apk --release

# App Bundle (Play Store 배포용)
flutter build appbundle --release
```

빌드 결과물: `build/app/outputs/`

### iOS

```bash
flutter build ios --release
```

이후 Xcode(`ios/Runner.xcworkspace`)에서 Archive 하여 App Store에 배포합니다.

## 테스트 및 린트

```bash
# 정적 분석
flutter analyze

# 테스트 실행
flutter test
```

## 프로젝트 구조

```
├── lib/            # Dart 소스 코드
│   └── main.dart   # 앱 진입점
├── test/           # 위젯 / 단위 테스트
├── android/        # Android 네이티브 프로젝트
├── ios/            # iOS 네이티브 프로젝트
└── pubspec.yaml    # 의존성 및 프로젝트 설정
```

## 컨벤션

- 린트 규칙: [flutter_lints](https://pub.dev/packages/flutter_lints) (`analysis_options.yaml`)
- 커밋 전 `flutter analyze` 통과 필수
