import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'stats_screen.dart'; // 통계 화면 이동을 위해 추가

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  String _myCode = '';
  List<Map<String, dynamic>> _familyMembers = [];
  bool _isAddButtonPressed = false;

  @override
  void initState() {
    super.initState();
    _loadFamilyData();
  }

  Future<void> _loadFamilyData() async {
    final prefs = await SharedPreferences.getInstance();
    final kakaoId = prefs.getString('kakaoId');
    
    // [v3.3] Firestore에서 최신 정보 동기화
    if (kakaoId != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(kakaoId).get();
      if (userDoc.exists) {
        final serverCode = userDoc.data()?['familyCode'];
        if (serverCode != null) {
          _myCode = serverCode;
          await prefs.setString('myFamilyCode', serverCode);
        }
      }
    }

    if (_myCode.isEmpty) {
      _myCode = prefs.getString('myFamilyCode') ?? '';
    }

    setState(() {
      final String? familyJson = prefs.getString('familyMembers');
      if (familyJson != null) {
        _familyMembers = List<Map<String, dynamic>>.from(json.decode(familyJson));
      } else {
        _familyMembers = [];
      }
    });
  }

  Future<void> _saveFamilyData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('familyMembers', json.encode(_familyMembers));
  }

  void _showAddFamilyDialog() {
    final TextEditingController codeController = TextEditingController();
    final TextEditingController memoController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text('가족 추가', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: '가족 초대 코드',
                  hintText: '예: A1B2C3',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: memoController,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: '메모 (별칭)',
                  hintText: '예: 엄마, 딸',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(minimumSize: const Size(60, 60)),
              child: const Text('취소', style: TextStyle(fontSize: 18)),
            ),
            ElevatedButton(
              onPressed: () {
                if (codeController.text.isNotEmpty && memoController.text.isNotEmpty) {
                  setState(() {
                    _familyMembers.add({
                      'code': codeController.text.trim(),
                      'name': memoController.text.trim(),
                    });
                  });
                  _saveFamilyData();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('가족이 성공적으로 연결되었습니다.', style: TextStyle(fontSize: 18))),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('코드와 메모를 모두 입력해주세요.', style: TextStyle(fontSize: 18))),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(60, 60),
                backgroundColor: const Color(0xFF0052CC),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('연결하기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showEditMemoDialog(int index) {
    final TextEditingController memoController = TextEditingController(text: _familyMembers[index]['name']);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text('메모 수정', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: memoController,
            style: const TextStyle(fontSize: 18),
            decoration: const InputDecoration(
              labelText: '메모 (별칭)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(minimumSize: const Size(60, 60)),
              child: const Text('취소', style: TextStyle(fontSize: 18)),
            ),
            ElevatedButton(
              onPressed: () {
                if (memoController.text.isNotEmpty) {
                  setState(() {
                    _familyMembers[index]['name'] = memoController.text.trim();
                  });
                  _saveFamilyData();
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(60, 60),
                backgroundColor: const Color(0xFF0052CC),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('저장', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDisconnect(int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text('연결 해제', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          content: const Text('정말로 이 가족과의 연결을 해제하시겠습니까?', style: TextStyle(fontSize: 18)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(minimumSize: const Size(60, 60)),
              child: const Text('취소', style: TextStyle(fontSize: 18)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _familyMembers.removeAt(index);
                });
                _saveFamilyData();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(60, 60),
                backgroundColor: Colors.red.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('해제하기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF0052CC);

    return Scaffold(
      appBar: AppBar(
        title: const Text('가족 연결', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('내 연결 코드 복사', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_myCode, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  IconButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _myCode));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('코드가 복사되었습니다.')));
                      }
                    },
                    icon: const Icon(Icons.copy_rounded),
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('이 코드를 가족에게 공유하여\n건강 데이터를 함께 관리하세요.', style: TextStyle(fontSize: 18)),
            
            const SizedBox(height: 40),
            const Text('데이터 열람 (가족 목록)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            // [v3.4] '나'를 목록 최상단에 고정 표시
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildMeTile(isDark, primaryColor),
            ),

            ..._familyMembers.asMap().entries.map((entry) {
              int index = entry.key;
              Map<String, dynamic> member = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildFamilyMemberTile(isDark, primaryColor, member['name'], member['code'], Icons.face_4_rounded, index),
              );
            }),
            
            const SizedBox(height: 12),
            GestureDetector(
              onTapDown: (_) => setState(() => _isAddButtonPressed = true),
              onTapUp: (_) {
                setState(() => _isAddButtonPressed = false);
                _showAddFamilyDialog();
              },
              onTapCancel: () => setState(() => _isAddButtonPressed = false),
              child: AnimatedScale(
                scale: _isAddButtonPressed ? 0.95 : 1.0,
                duration: const Duration(milliseconds: 100),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
                    border: Border.all(color: isDark ? Colors.white24 : Colors.black12, style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline_rounded, color: Colors.grey, size: 28),
                      SizedBox(width: 8),
                      Text('가족 코드 입력하여 연결하기', style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // [v3.4] 나를 위한 전용 타일 (에딧/삭제 버튼 없음)
  Widget _buildMeTile(bool isDark, Color primaryColor) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen(initialCreator: '나'))),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.1), // '나'는 배경색으로 차별화
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: primaryColor,
              radius: 28,
              child: const Icon(Icons.person, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('나 (본인)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('내 건강 기록 열람하기 >', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 32, color: primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyMemberTile(bool isDark, Color primaryColor, String name, String code, IconData icon, int index) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => StatsScreen(initialCreator: name)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: primaryColor.withValues(alpha: 0.2),
              radius: 28,
              child: Icon(icon, color: primaryColor, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        padding: EdgeInsets.zero,
                        onPressed: () => _showEditMemoDialog(index),
                      ),
                    ],
                  ),
                  Text('코드: $code (기록 열람하기 >)', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: () => _confirmDisconnect(index),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(60, 60),
                foregroundColor: Colors.red.shade800,
                side: BorderSide(color: Colors.red.shade800),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('해제하기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}
