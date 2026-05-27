import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'login_screen.dart';

class MyPageScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;

  const MyPageScreen({super.key, required this.onThemeToggle});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  String _userName = '사용자';
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName') ?? '사용자';
      _userEmail = prefs.getString('userEmail') ?? '';
    });
  }

  Future<void> _handleLogout() async {
    try {
      await UserApi.instance.logout();
    } catch (e) {
      debugPrint('Kakao logout error: $e');
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _handleWithdrawal() async {
    bool? confirm1 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: const Text('정말로 탈퇴하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('탈퇴 진행'),
          ),
        ],
      ),
    );

    if (confirm1 != true) return;

    if (!mounted) return;

    bool? confirm2 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('경고: 데이터 영구 삭제'),
        content: const Text('탈퇴 시 모든 건강 기록 및 개인 데이터가 영구적으로 삭제됩니다.\n계속하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('완전 삭제 및 탈퇴'),
          ),
        ],
      ),
    );

    if (confirm2 != true) return;

    // [RULES.md v2.0] 회원 탈퇴 시 관련 데이터(health_records) 일괄 삭제 수행
    try {
      final prefs = await SharedPreferences.getInstance();
      final myCode = prefs.getString('myFamilyCode');
      
      if (myCode != null && myCode.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        final snapshots = await FirebaseFirestore.instance
            .collection('health_records')
            .where('creatorCode', isEqualTo: myCode)
            .get();
            
        for (var doc in snapshots.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        debugPrint('Firestore data deleted successfully for code: $myCode');
      }
    } catch (e) {
      debugPrint('Firestore delete error during withdrawal: $e');
    }

    try {
      // 카카오 연결 끊기 (회원 탈퇴)
      await UserApi.instance.unlink();
    } catch (e) {
      debugPrint('Kakao unlink error: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('회원 탈퇴가 완료되었습니다.')),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('마이페이지', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // 프로필 정보 영역
          const Text('내 정보', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF0052CC).withValues(alpha: 0.2),
                  child: const Icon(Icons.person, size: 36, color: Color(0xFF0052CC)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_userName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(_userEmail.isNotEmpty ? _userEmail : '이메일 정보 없음', 
                        style: const TextStyle(fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.grey),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('닉네임 수정 기능 준비중')),
                    );
                  },
                )
              ],
            ),
          ),
          const SizedBox(height: 32),

          // 환경 설정 영역
          const Text('환경 설정', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode, size: 28),
            title: const Text('다크모드 (화면 테마)', style: TextStyle(fontSize: 18)),
            trailing: Switch(
              value: isDark,
              onChanged: (val) => widget.onThemeToggle(),
              activeThumbColor: const Color(0xFF0052CC),
            ),
          ),
          const Divider(height: 32),

          // 계정 관리 영역
          const Text('계정 관리', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout, size: 28),
            title: const Text('로그아웃', style: TextStyle(fontSize: 18)),
            onTap: _handleLogout,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_off, color: Colors.red, size: 28),
            title: const Text('회원 탈퇴', style: TextStyle(fontSize: 18, color: Colors.red)),
            onTap: _handleWithdrawal,
          ),
        ],
      ),
    );
  }
}
