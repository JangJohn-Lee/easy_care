import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  String _myCode = '';
  List<Map<String, String>> _familyMembers = [];
  bool _isAddButtonPressed = false;

  @override
  void initState() {
    super.initState();
    _loadFamilyData();
  }

  Future<void> _loadFamilyData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _myCode = prefs.getString('myFamilyCode') ?? _generateRandomCode();
      if (!prefs.containsKey('myFamilyCode')) {
        prefs.setString('myFamilyCode', _myCode);
      }
      
      // Load mock family members for prototype
      _familyMembers = [
        {'name': '김가족', 'relation': '딸'}
      ];
    });
  }

  String _generateRandomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  void _showAddFamilyDialog() {
    final TextEditingController codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text('가족 초대 코드 입력', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: codeController,
            style: const TextStyle(fontSize: 18),
            decoration: const InputDecoration(
              hintText: '예: A1B2C3',
              hintStyle: TextStyle(fontSize: 18),
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
                if (codeController.text.isNotEmpty) {
                  setState(() {
                    _familyMembers.add({'name': '새 가족', 'relation': '가족'});
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('가족이 성공적으로 연결되었습니다.', style: TextStyle(fontSize: 18))),
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(32), // RULES.md 반영: 카드 32px
                border: Border.all(color: primaryColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('내 연결 코드', style: TextStyle(fontSize: 18, color: primaryColor, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _myCode.isEmpty ? '로딩중...' : _myCode, 
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2.0),
                      ),
                      IconButton(
                        constraints: const BoxConstraints(minWidth: 60, minHeight: 60),
                        onPressed: () async {
                          if (_myCode.isNotEmpty) {
                            await Clipboard.setData(ClipboardData(text: _myCode));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('코드가 복사되었습니다.', style: TextStyle(fontSize: 18))),
                              );
                            }
                          }
                        },
                        icon: Icon(Icons.copy_rounded, size: 28, color: primaryColor),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('이 코드를 가족에게 공유하여\n건강 데이터를 함께 관리하세요.', style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('연결된 가족', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ..._familyMembers.asMap().entries.map((entry) {
              int index = entry.key;
              Map<String, String> member = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildFamilyMemberTile(isDark, primaryColor, member['name']!, member['relation']!, Icons.face_4_rounded, index),
              );
            }),
            const SizedBox(height: 12),
            // RULES.md 반영: AnimatedScale 터치 피드백
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
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
                    border: Border.all(color: isDark ? Colors.white24 : Colors.black12, style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(28), // RULES.md 반영: 메뉴 카드 28px
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

  Widget _buildFamilyMemberTile(bool isDark, Color primaryColor, String name, String relation, IconData icon, int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.white,
        borderRadius: BorderRadius.circular(28), // RULES.md 반영: 메뉴 카드 28px
        border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: primaryColor.withOpacity(0.2),
            radius: 28,
            child: Icon(icon, color: primaryColor, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(relation, style: const TextStyle(fontSize: 18, color: Colors.grey)),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => _confirmDisconnect(index),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(60, 60),
              foregroundColor: Colors.red.shade800, // RULES.md 반영: Danger 색상
              side: BorderSide(color: Colors.red.shade800),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('연결 해제', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}
