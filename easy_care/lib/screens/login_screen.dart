import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dashboard_screen.dart';
import '../main.dart'; // toggleTheme 접근용

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (isLoggedIn) {
      if (!mounted) return;
      _navigateToDashboard();
    }
  }

  Future<void> _handleKakaoLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      bool isInstalled = await isKakaoTalkInstalled();
      if (isInstalled) {
        try {
          await UserApi.instance.loginWithKakaoTalk();
        } catch (e) {
          if (e is PlatformException && e.code == 'CANCELED') {
            return;
          }
          // 카카오톡에 연결된 카카오계정이 없는 경우, 카카오계정으로 로그인
          await UserApi.instance.loginWithKakaoAccount(prompts: [Prompt.login]);
        }
      } else {
        await UserApi.instance.loginWithKakaoAccount(prompts: [Prompt.login]);
      }

      // 로그인 성공 시 정보 가져오기
      User user = await UserApi.instance.me();
      final String kakaoId = user.id.toString();
      final String nickname = user.kakaoAccount?.profile?.nickname ?? '사용자';
      final String email = user.kakaoAccount?.email ?? '';

      // [v3.3] Firestore에서 사용자 고유 코드 관리
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(kakaoId).get();
      String familyCode;
      
      if (userDoc.exists) {
        // 기존 회원이면 저장된 코드 사용
        familyCode = userDoc.data()?['familyCode'] ?? _generateRandomCode();
      } else {
        // 신규 회원이면 코드 생성 및 Firestore 저장
        familyCode = _generateRandomCode();
        await FirebaseFirestore.instance.collection('users').doc(kakaoId).set({
          'nickname': nickname,
          'email': email,
          'familyCode': familyCode,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      // 로그인 상태 및 코드 로컬 저장 (동기화)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('kakaoId', kakaoId);
      await prefs.setString('userName', nickname);
      await prefs.setString('userEmail', email);
      await prefs.setString('myFamilyCode', familyCode);

      if (!mounted) return;
      _navigateToDashboard();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 실패: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _generateRandomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  void _navigateToDashboard() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ModernDashboard(
          onThemeToggle: (context.findAncestorStateOfType<EasyCareAppState>()!).toggleTheme,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.health_and_safety_rounded, size: 110, color: Color(0xFF0052CC)),
            const SizedBox(height: 16),
            const Text(
              '혈당도우미',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 60),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: _handleKakaoLogin,
                    icon: const Icon(Icons.chat_bubble, color: Colors.black87),
                    label: const Text(
                      '카카오로 로그인 / 회원가입',
                      style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFEE500),
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
