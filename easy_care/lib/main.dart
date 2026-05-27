import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 1. dotenv 임포트 추가
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'services/notification_service.dart';

void main() async {
  // Flutter 엔진 초기화 확인
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("🚀 App Starting: WidgetsFlutterBinding initialized");

  // 2. .env 파일 로드 (가장 먼저 수행)
  try {
    await dotenv.load(fileName: ".env");
    debugPrint("✅ .env file loaded successfully");
  } catch (e) {
    debugPrint(
      "⚠️ Warning: .env file not found. Make sure it exists in the root directory.",
    );
  }

  // 알림 서비스 초기화
  await NotificationService().init();
  debugPrint("✅ NotificationService initialized");

  // 3. 카카오 SDK 초기화
  String kakaoNativeKey = dotenv.env['KAKAO_NATIVE_APP_KEY'] ?? "";
  String kakaoJsKey = dotenv.env['KAKAO_JS_APP_KEY'] ?? "";

  if (kakaoNativeKey.isEmpty || kakaoJsKey.isEmpty) {
    debugPrint("❌ CRITICAL: Kakao Keys are missing in .env file!");
  } else {
    debugPrint("🔑 Kakao Keys loaded: Native(OK), JS(OK)");
  }

  KakaoSdk.init(nativeAppKey: kakaoNativeKey, javaScriptAppKey: kakaoJsKey);
  debugPrint("✅ KakaoSdk initialized");

  // Firebase 초기화
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("✅ Firebase initialized successfully");
  } catch (e) {
    debugPrint("❌ Firebase initialization failed: $e");
  }

  runApp(const EasyCareApp());
}

class EasyCareApp extends StatefulWidget {
  const EasyCareApp({super.key});

  @override
  State<EasyCareApp> createState() => EasyCareAppState();
}

class EasyCareAppState extends State<EasyCareApp> {
  // [규칙 1] 전역 테마 모드 관리
  ThemeMode _themeMode = ThemeMode.light;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '혈당도우미',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,

      // --- 라이트 모드 테마 ---
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0052CC),
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8F9FE),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(fontSize: 18, color: Colors.black87),
          bodyMedium: TextStyle(fontSize: 16, color: Colors.black54),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 60),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),

      // --- 다크 모드 테마 ---
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0052CC),
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF010813),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          bodyLarge: TextStyle(fontSize: 18, color: Colors.white70),
          bodyMedium: TextStyle(fontSize: 16, color: Colors.white54),
        ),
      ),

      home: const LoginScreen(),
    );
  }
}
