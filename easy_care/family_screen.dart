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
  List<String> _familyList = [];
  final Color _primaryColor = const Color(0xFF0052CC);
  final Color _dangerColor = Colors.red.shade800;

  @override
  void initState() {
    super.initState();
    _loadFamilyData();
  }

  // 가족 데이터 및 내 코드 로드/생성
  Future<void> _loadFamilyData() async {
    final prefs = await SharedPreferences.getInstance();
    String? code = prefs.getString('my_family_code');
    
    // 코드 없으면 신규 생성 (6자리 대문자/숫자 조합)
    if (code == null) {
      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      code = List.generate(6, (index) => chars[Random().nextInt(chars.length)]).join();
      await prefs.setString('my_family_code', code);
    }

    setState(() {
      _myCode = code!;
      _familyList = prefs.getStringList('family_list') ?? [];
    });
  }

  // 가족 추가 다이얼로그
  Future<void> _showAddFamilyDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('가족 연결하기', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '가족의 초대 코드 6자리를 입력하세요',
            border: OutlineInputBorder(),
          ),
          inputFormatters: [LengthLimitingTextInputFormatter(6)],
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            onPressed: () async {
              if (controller.text.length == 6) {
                final prefs = await SharedPreferences.getInstance();
                _familyList.add(controller.text);
                await prefs.setStringList('family_list', _familyList);
                setState(() {});
                if (!mounted) return;
                Navigator.pop(context);
              }
            },
            child: const Text('연결', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 가족 삭제 (Double Check)
  Future<void> _removeFamily(int index) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('연결 해제'),
        content: const Text('정말로 이 가족과의 연결을 해제하시겠습니까?\n상대방의 건강 데이터를 볼 수 없게 됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: _dangerColor),
            child: const Text('해제하기'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _familyList.removeAt(index);
      });
      await prefs.setStringList('family_list', _familyList);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('가족 연결', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 내 코드 섹션 (RULES.md: BorderRadius 32px)
            const Text('내 연결 코드', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: _primaryColor.withOpacity(0.3), width: 2),
              ),
              child: Column(
                children: [
                  Text(_myCode, style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: _primaryColor, letterSpacing: 8)),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _myCode));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('코드가 복사되었습니다.')));
                    },
                    child: AnimatedScale(
                      scale: 1.0,
                      duration: const Duration(milliseconds: 100),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(color: _primaryColor, borderRadius: BorderRadius.circular(16)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('코드 복사하기', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // 2. 가족 목록 섹션 (RULES.md: BorderRadius 28px)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('연결된 가족', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text('${_familyList.length}명', style: TextStyle(fontSize: 18, color: _primaryColor)),
              ],
            ),
            const SizedBox(height: 12),
            if (_familyList.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text('연결된 가족이 없습니다.\n코드를 공유해 가족을 추가해보세요.', 
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.grey)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _familyList.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _primaryColor.withOpacity(0.2),
                          child: Icon(Icons.person, color: _primaryColor),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text('가족 멤버 (${_familyList[index]})', 
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                        ),
                        IconButton(
                          onPressed: () => _removeFamily(index),
                          icon: Icon(Icons.link_off, color: _dangerColor),
                          constraints: const BoxConstraints(minWidth: 60, minHeight: 60), // 터치 영역 준수
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
      // 3. 가족 추가 버튼 (AnimatedScale 적용)
      floatingActionButton: Transform.scale(
        scale: 1.1,
        child: FloatingActionButton.extended(
          onPressed: _showAddFamilyDialog,
          backgroundColor: _primaryColor,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('가족 추가', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

class ScaleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const ScaleButton({super.key, required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(scale: 0.95, duration: const Duration(milliseconds: 100), child: child),
    );
  }
}