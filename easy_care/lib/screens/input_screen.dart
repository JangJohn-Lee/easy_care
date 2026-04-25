import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/health_stat.dart'; // 진단 엔진 사용

class InputScreen extends StatefulWidget {
  const InputScreen({super.key});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  // [규칙 2] 측정 시점 필수 관리
  String _selectedType = '공복'; 
  final TextEditingController _sugarController = TextEditingController();
  final TextEditingController _sysController = TextEditingController();
  final TextEditingController _diaController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  // --- [규칙 2] 통합 진단 엔진을 활용한 저장 로직 ---
  Future<void> _handleSave() async {
    final String sugarText = _sugarController.text.trim();
    if (sugarText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('혈당 수치는 반드시 입력해야 합니다!'))
      );
      return;
    }

    final int sugar = int.parse(sugarText);
    final int? sys = int.tryParse(_sysController.text);
    final int? dia = int.tryParse(_diaController.text);

    // 임시 객체를 생성하여 진단 결과 미리보기 (v1.5 규칙 준수)
    final tempRecord = HealthRecord(
      id: '',
      type: _selectedType,
      sugar: sugar,
      systolic: sys,
      diastolic: dia,
      memo: _memoController.text,
      timestamp: DateTime.now(),
    );

    final sugarInfo = tempRecord.sugarStatus;
    final bpInfo = tempRecord.bloodPressureStatus;

    // 저장 전 확인 다이얼로그 (어르신 맞춤형 피드백)
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("측정 결과: ${sugarInfo['label']}", 
                   style: TextStyle(color: sugarInfo['color'], fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sugarInfo['msg'], style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            if (sys != null) ...[
              const Divider(),
              Text("혈압 상태: ${bpInfo['label']}", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(bpInfo['msg']),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("수정하기")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: sugarInfo['color'], foregroundColor: Colors.white),
            child: const Text("확인 및 저장"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('health_records').add({
        'type': _selectedType,
        'sugar': sugar,
        'systolic': sys,
        'diastolic': dia,
        'memo': _memoController.text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context); // 저장 후 대시보드로 이동
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('건강 기록하기')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- [규칙 2] 측정 시점 선택 (Type Selector) ---
            const Text("언제 측정하셨나요?", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: ['공복', '식전', '식후'].map((type) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(type, style: const TextStyle(fontSize: 18)),
                    ),
                    selected: _selectedType == type,
                    onSelected: (val) => setState(() => _selectedType = type),
                    selectedColor: const Color(0xFF0052CC),
                    labelStyle: TextStyle(color: _selectedType == type ? Colors.white : Colors.black),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // --- 입력 필드 섹션 ---
            _buildInputField('혈당 수치 (mg/dL)', _sugarController, Icons.water_drop, Colors.redAccent),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildInputField('최고혈압(SYS)', _sysController, Icons.arrow_upward, Colors.orange)),
                const SizedBox(width: 12),
                Expanded(child: _buildInputField('최저혈압(DIA)', _diaController, Icons.arrow_downward, Colors.blue)),
              ],
            ),
            const SizedBox(height: 20),
            _buildInputField('메모 (식단 등)', _memoController, Icons.edit_note, Colors.grey, isMemo: true),
            
            const SizedBox(height: 40),
            
            // 저장 버튼 (60px 터치 영역 확보)
            SizedBox(
              width: double.infinity,
              height: 65,
              child: ElevatedButton(
                onPressed: _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0052CC),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('기록 완료하기', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, IconData icon, Color color, {bool isMemo = false}) {
    return TextField(
      controller: controller,
      keyboardType: isMemo ? TextInputType.text : TextInputType.number,
      inputFormatters: isMemo ? [] : [FilteringTextInputFormatter.digitsOnly],
      maxLines: isMemo ? 3 : 1,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 16),
        prefixIcon: Icon(icon, color: color, size: 28),
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      ),
    );
  }
}