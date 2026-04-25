import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class OCRService {
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.korean);

  /// 이미지에서 건강 데이터를 추출하는 핵심 함수
  Future<Map<String, int?>> extractHealthData(XFile image) async {
    final inputImage = InputImage.fromFilePath(image.path);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    final String fullText = recognizedText.text.replaceAll(' ', ''); // 공백 제거 후 분석

    // 숫자만 추출
    List<int> numbers = RegExp(r'\d+')
        .allMatches(fullText)
        .map((m) => int.parse(m.group(0)!))
        .toList();

    Map<String, int?> result = {
      'sugar': null,
      'systolic': null,
      'diastolic': null,
    };

    if (numbers.isEmpty) return result;

    // 규칙: 숫자 1개 -> 혈당(sugar)
    if (numbers.length == 1) {
      result['sugar'] = numbers[0];
    } 
    // 규칙: 숫자 2개 이상 및 키워드 판단
    else {
      if (fullText.contains('혈압')) {
        // 숫자들 중 가장 큰 값을 수축기, 두 번째를 이완기로 판단
        numbers.sort((a, b) => b.compareTo(a));
        result['systolic'] = numbers[0];
        result['diastolic'] = numbers[1];
      } else if (fullText.contains('혈당') || numbers.length >= 2) {
        // 혈당 키워드가 있거나 혈압 키워드가 없는 경우 첫 번째 숫자를 혈당으로 판단
        result['sugar'] = numbers[0];
      }
    }

    return result;
  }

  void dispose() {
    _textRecognizer.close();
  }
}