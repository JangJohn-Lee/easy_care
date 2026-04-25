import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
// 정확한 모델 경로 및 클래스명(HealthRecord) 사용
import '../models/health_stat.dart'; 

class InputScreen extends StatefulWidget {
  const InputScreen({super.key});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  // [RULES.md v1.6] 상태 관리 및 컨트롤러
  String _selectedType = '공복';
  final TextEditingController _sugarController = TextEditingController();
  final TextEditingController _sysController = TextEditingController();
  final TextEditingController _diaController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.korean);
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _textRecognizer.close();
    _sugarController.dispose();
    _sysController.dispose();
    _diaController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  // [RULES.md v1.6] 지능형 OCR 입력 로직
  Future<void> _processOCR() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
    );
    
    if (image == null) return;

    // 로딩 인디케이터 표시 (비동기 가드 적용)
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 재촬영 시 기존 필드 초기화
      setState(() {
        _sugarController.clear();
        _sysController.clear();
        _diaController.clear();
      });

      final inputImage = InputImage.fromFilePath(image.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final String fullText = recognizedText.text.replaceAll(' ', '');

      // 숫자 추출 및 지능형 판단
      List<int> numbers = RegExp(r'\d+')
          .allMatches(fullText)
          .map((m) => int.parse(m.group(0)!))
          .toList();

      if (numbers.isNotEmpty) {
        setState(() {
          if (numbers.length == 1) {
            _sugarController.text = numbers[0].toString();
          } else {
            if (fullText.contains('혈압')) {
              numbers.sort((a, b) => b.compareTo(a)); // 큰 수: 수축기
              _sysController.text = numbers[0].toString();
              _diaController.text = numbers[1].toString();
            } else {
              _sugarController.text = numbers[0].toString();
            }
          }
        });
      }
      
      if (mounted) Navigator.pop(context); // 로딩 닫기
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('인식 오류가 발생했습니다.'))
        );
      }
    }
  }

  // [RULES.md v1.6] 데이터 저장 로직
  Future<void> _handleSave() async {
    final String sugarText = _sugarController.text.trim();
    if (sugarText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('혈당 수치를 입력해주세요.'))
      );
      return;
    }

    // HealthRecord 객체 생성
    final record = HealthRecord(
      id: '', 
      type: _selectedType,
      sugar: int.parse(sugarText),
      systolic: int.tryParse(_sysController.text),
      diastolic: int.tryParse(_diaController.text),
      memo: _memoController.text,
      timestamp: DateTime.now(),
    );

    // 저장 전 확인 다이얼로그 (진단 문구 포함 수정본)
    if (!mounted) return;
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("기록을 확인하세요", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("시점: ${record.type}", style: const TextStyle(fontSize: 18)),
            const Divider(),
            // 혈당 수치 표시
            Text("혈당: ${record.sugar} mg/dL", 
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: record.sugarStatus['color'])),
            // 상세 진단 메시지 표시 (추가됨)
            Text("${record.sugarStatus['msg']}", 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: record.sugarStatus['color'])),
            
            if (record.systolic != null) ...[
              const SizedBox(height: 12),
              // 혈압 수치 표시
              Text("혈압: ${record.systolic}/${record.diastolic} mmHg", 
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
              // 혈압 상세 메시지 표시 (추가됨)
              Text("${record.bloodPressureStatus['msg']}", 
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.blue)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("수정")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052CC), foregroundColor: Colors.white),
            child: const Text("저장"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // toMap()을 활용한 Firestore 저장
      await FirebaseFirestore.instance.collection('health_records').add(record.toMap());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('건강 기록 입력')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // OCR 촬영 버튼 (터치 영역 65px 확보)
            SizedBox(
              width: double.infinity,
              height: 65,
              child: OutlinedButton.icon(
                onPressed: _processOCR,
                icon: const Icon(Icons.camera_alt, size: 28),
                label: const Text('사진으로 자동 입력', 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF0052CC), width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 측정 시점 선택
            const Text("언제 측정하셨나요?", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: ['공복', '식전', '식후'].map((type) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
            const SizedBox(height: 30),

            // 입력 필드 (수치 22px+ 적용)
            _buildInputField('혈당 수치 (mg/dL)', _sugarController, Icons.water_drop, Colors.redAccent),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: _buildInputField('최고(수축기)', _sysController, Icons.arrow_upward, Colors.orange)),
                const SizedBox(width: 10),
                Expanded(child: _buildInputField('최저(이완기)', _diaController, Icons.arrow_downward, Colors.blue)),
              ],
            ),
            const SizedBox(height: 15),
            _buildInputField('메모', _memoController, Icons.notes, Colors.grey, isMemo: true),
            
            const SizedBox(height: 40),
            
            // 저장 버튼 (65px 높이)
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
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      ),
    );
  }
}