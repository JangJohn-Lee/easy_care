# EasyCare v1.7 & v1.8 반영 수정 이력

## 1. 모델 계층 업데이트 (`health_stat.dart`)
- `mealType`, `stepType` 대신 `type`으로 필드 통합
- Firestore `toMap()`, `fromFirestore()`에 `type` 파라미터 적용 반영

## 2. 대시보드 스크린 업데이트 (`dashboard_screen.dart`)
- 하단 혈압 수치 표시 글자 크기 상향 (혈당 대비 60% 비율 고려: 20px -> 38px)
- 회원 탈퇴 등 기타 기능 대비 메뉴 구조 확장성 검토

## 3. 입력 스크린 업데이트 (`input_screen.dart`)
- **지능형 OCR 입력 로직 개선**:
  - 사진 촬영 시 기존 필드 초기화 및 반복 촬영 로직 강화
  - 숫자 1개: 혈당값 자동 입력
  - 숫자 2개 이상: 조건에 따른 혈당 우선 추출
  - 숫자 3개 이상: 혈압 키워드가 있을 시 수축기(큰 값)와 이완기(작은 값) 자동 정렬 및 분리 추출
- 촬영 버튼 텍스트 변경: '사진으로 자동 입력' -> '사진 촬영 / 재촬영'

## 4. 통계 스크린 업데이트 (`stats_screen.dart`)
- 앱 상단에 리포트 다운로드 아이콘 버튼 추가
- **상세 로그 UI 개선**: 
  - `_showDayDetail` 함수에서 `상태(공복 등) | 메모: 내용` 형식으로 출력 방식 수정
  - 정상/낮음/높음 등 수치 상태에 따른 조건부 폰트 색상(혈당, 혈압 진단 정보 연동) 적용

## 5. 로그인 스크린 업데이트 (`login_screen.dart`)
- 카카오 버튼 텍스트를 '카카오로 로그인 / 회원가입'으로 명확하게 수정하여 인증 흐름 안내

## 6. 메뉴 카드 위젯 업데이트 (`menu_card.dart`)
- 터치 영역 내 중요 텍스트 크기를 어르신 친화적으로 19px에서 22px로 확대 (굵게)

## 7. 메인 파일 검토 (`main.dart`)
- 전반적인 테마 및 초기화 로직 확인 (특별한 수정 소요 없음)

## 8. 로드맵 우선순위 변경
- 사용자 요청에 따라 Step 5 잔여 작업(Excel/PDF 리포트 추출 등) 및 Step 6 보다, **Step 7 (소셜 연동 및 커뮤니티, 회원가입/카카오 로그인, 마이페이지, 회원탈퇴 기능)** 을 우선적으로 구현하도록 로드맵 일정을 조정함.

## 9. Step 7 1단계 및 2단계 구현 (마이페이지 및 카카오 로그인 연동)
- `shared_preferences` 패키지 추가하여 로컬 세션 유지
- **로그인 (`login_screen.dart`)**: 카카오 SDK(`UserApi.instance.loginWithKakaoTalk`)를 활용한 실제 인증 로직 적용 및 로그인 상태 유지 구현
- **마이페이지 (`my_page_screen.dart`) 신규 생성**:
  - 카카오 프로필 정보(닉네임, 이메일) 표시
  - 전역 다크모드 스위치 지원
  - 카카오 로그아웃(`UserApi.instance.logout`) 및 세션 초기화 구현
  - 회원 탈퇴 기능(`UserApi.instance.unlink`) 구현 및 Double Check 경고 팝업 적용
- **대시보드 (`dashboard_screen.dart`) 업데이트**:
  - 카카오 프로필에서 가져온 사용자 이름을 상단 인삿말에 표시하도록 `StatefulWidget`으로 변경
  - 기존 '로그아웃' 메뉴 카드를 '마이페이지'로 변경하고 `MyPageScreen`으로 라우팅 처리

## 10. Step 7 3단계 구현 (가족 연결 UI 및 스마트 푸시 알람)
- **푸시 알람 (`notification_service.dart`) 생성**:
  - `flutter_local_notifications` 및 `timezone` 패키지를 활용한 로컬 알림 서비스 구현
  - `input_screen.dart`에서 '식전' 측정 기록 저장 시 식후 측정을 유도하는 알람 스케줄링(시연을 위해 10초 뒤로 세팅) 자동 등록 구현
- **가족 연결 (`family_screen.dart`) 신규 생성**:
  - 내 연결 코드 표시 및 복사 기능 UI
  - 연결된 가족 리스트 및 가족 코드 입력 초대 UI 구축
  - `dashboard_screen.dart`의 '가족 연결' 메뉴에서 해당 화면으로 라우팅 연결

## 11. Step 7 가족 연결 UI 고도화 및 디자인 원칙(RULES.md) 전면 적용
- **가족 연결 기능 (`family_screen.dart`) 완벽 구현**:
  - `SharedPreferences`를 활용하여 6자리 영문/숫자 혼합 고유 가족 초대 코드 임의 생성 및 유지 로직 구현.
  - `flutter/services.dart`의 `ClipboardData`를 활용하여 내 연결 코드 클립보드 복사 기능 및 스낵바 알림 추가.
  - 가족 초대 코드 입력 다이얼로그 추가 및 연결된 가족 리스트 상태(동적 추가/삭제) 관리.
  - 삭제 시 실수 방지를 위한 'Double Check' 경고 다이얼로그 추가.
  - `RULES.md` 공통 디자인 시스템 전면 반영:
    - **Primary Color:** 화면 전체 테마(배경, 아이콘, 타이틀 등)에 메인 색상(`Color(0xFF0052CC)`) 통일 적용.
    - **터치 영역 및 가독성:** 모든 터치 가능한 요소의 최소 영역을 `60px`(`minimumSize`, `BoxConstraints` 활용)로 확보하고, 본문 폰트 최소 사이즈를 `18px`(제목 `22px` 이상)로 상향.
    - **인터랙션 및 곡률:** 터치 피드백을 위한 `AnimatedScale(scale: 0.95)` 반영. 대시보드 카드 `32px`, 메뉴 카드 및 리스트 `28px`, 기본 버튼 `16px` 모서리 곡률 통일.
    - **위험 상태 색상:** 가족 연결 해제 버튼 및 팝업 확인 버튼에 Danger 색상(`Colors.red.shade800`) 적용.

## 12. 안드로이드 빌드 환경 수정 (`android/app/build.gradle.kts`)
- `flutter_local_notifications` 패키지 요구사항 충족 및 의존성 충돌 해결을 위해 `coreLibraryDesugaring`에 사용되는 `desugar_jdk_libs` 버전을 `2.1.4`에서 `2.1.5`로 상향 적용하여 안드로이드 앱 빌드 오류 해결.

## 13. 가족 연결 기능 고도화 (데이터 공유 및 메모 기능)
- **가족 연결 (`family_screen.dart`)**:
  - 가족 코드 등록 시 식별용 '메모(별칭)' 입력 다이얼로그 추가.
  - 리스트에서 연필(Edit) 아이콘을 눌러 메모 내용을 언제든 수정 가능하도록 구현.
  - 가족 리스트 상태를 `SharedPreferences`를 사용해 로컬 기기에 JSON 형태로 영구 보존하도록 연동.
- **데이터 모델 및 입력 (`health_stat.dart`, `input_screen.dart`)**:
  - `HealthRecord` 데이터 모델에 `creatorCode` 속성을 추가.
  - Firestore에 기록을 저장할 때, 내 가족 코드(`myFamilyCode`)를 함께 담아 업로드하도록 로직 수정.
- **통계 및 대시보드 (`stats_screen.dart`, `dashboard_screen.dart`)**:
  - `stats_screen.dart`에서 화면 진입 시 내 코드와 연결된 가족들의 코드를 배열로 묶어 Firestore에 `whereIn` 조건으로 질의하도록 변경하여, 가족들의 기록을 캘린더와 차트에 병합 노출. (이후 로컬 필터링으로 수정하여 색인 문제 해결)
  - `dashboard_screen.dart`에서는 메인 대시보드 성격에 맞게 내 코드(`myFamilyCode`) 데이터만 필터링하여 노출하도록 수정.

## 14. 데이터 내보내기 (Excel 리포트 추출) 기능 구현
- `excel`, `path_provider`, `share_plus` 패키지 추가.
- `stats_screen.dart`에 기간 설정(`showDateRangePicker`)을 통한 리포트 추출 UI 추가.
- 선택된 기간의 데이터를 '일시', '구분', '혈당', '혈압(수축기/이완기)', '메모' 컬럼을 갖춘 엑셀(`.xlsx`) 파일로 생성하고, OS 기본 공유 기능을 통해 내보낼 수 있도록 구현.