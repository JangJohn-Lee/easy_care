import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import '../main.dart'; // toggleTheme 접근용

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

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
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ModernDashboard(
                      onThemeToggle: (context.findAncestorStateOfType<EasyCareAppState>()!).toggleTheme,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.chat_bubble, color: Colors.black87),
              label: const Text(
                '카카오로 시작하기',
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