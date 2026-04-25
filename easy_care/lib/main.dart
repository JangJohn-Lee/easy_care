import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 1. dotenv 임포트 추가
import 'firebase_options.dart';
import 'screens/login_screen.dart';

void main() async {
  // Flutter 엔진 초기화 확인
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. .env 파일 로드 (가장 먼저 수행)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // .env 파일이 없을 경우 대비 (에러 로그 출력)
    debugPrint("Warning: .env file not found. Make sure it exists in the root directory.");
  }

  // 3. 카카오 SDK 초기화 (직접 쓴 키 대신 환경 변수 사용)
  // [보안] 깃허브에는 키가 올라가지 않도록 처리됨
  String kakaoNativeKey = dotenv.env['KAKAO_NATIVE_APP_KEY'] ?? "";
  KakaoSdk.init(nativeAppKey: kakaoNativeKey);
  
  // Firebase 초기화
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
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
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '혈당도우미 EasyCare',
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          bodyLarge: TextStyle(fontSize: 18, color: Colors.white70),
          bodyMedium: TextStyle(fontSize: 16, color: Colors.white54),
        ),
      ),
      
      home: const LoginScreen(),
    );
  }
}